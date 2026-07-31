package com.heyairu.monogatari_assistant_fe

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.heyairu.monogatari_assistant/file"
    private val SELECT_BACKUP_DIRECTORY_REQUEST = 4101
    private val BACKUP_PREFS = "monogatari_backup_preferences"
    private val BACKUP_TREE_URI_KEY = "auto_backup_tree_uri"
    private val BACKUP_FOLDER_NAME = "MonoAshi_Backup"
    private var pendingBackupDirectoryResult: MethodChannel.Result? = null

    private fun buildInitialTreeUri(path: String? = null): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return null
        }

        val relativePath = if (path.isNullOrBlank()) {
            Environment.DIRECTORY_DOCUMENTS
        } else {
            val storageRoot = Environment.getExternalStorageDirectory().absolutePath
            val normalizedRoot = File(storageRoot).canonicalPath
            val normalizedTarget = File(path).canonicalPath
            if (!normalizedTarget.startsWith(normalizedRoot)) {
                return DocumentsContract.buildTreeDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:${Environment.DIRECTORY_DOCUMENTS}"
                )
            }

            normalizedTarget
                .removePrefix(normalizedRoot)
                .trimStart(File.separatorChar)
                .replace(File.separatorChar, '/')
        }
        val documentId = if (relativePath.isEmpty()) {
            "primary:"
        } else {
            "primary:$relativePath"
        }

        return DocumentsContract.buildTreeDocumentUri(
            "com.android.externalstorage.documents",
            documentId
        )
    }

    private fun selectedBackupTreeUri(): String? {
        return getSharedPreferences(BACKUP_PREFS, MODE_PRIVATE)
            .getString(BACKUP_TREE_URI_KEY, null)
    }

    private fun saveSelectedBackupTreeUri(uri: Uri) {
        getSharedPreferences(BACKUP_PREFS, MODE_PRIVATE)
            .edit()
            .putString(BACKUP_TREE_URI_KEY, uri.toString())
            .apply()
    }

    private fun findChildDirectoryUri(treeUri: Uri, parentDocumentId: String, displayName: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocumentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )

        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val childName = cursor.getString(nameIndex)
                val childMime = cursor.getString(mimeIndex)
                if (childName == displayName && childMime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    val childId = cursor.getString(idIndex)
                    return DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                }
            }
        }

        return null
    }

    private fun ensureAutoBackupDirectoryUri(treeUri: Uri): Uri {
        val parentDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocumentId)
        findChildDirectoryUri(treeUri, parentDocumentId, BACKUP_FOLDER_NAME)?.let { return it }
        return DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            BACKUP_FOLDER_NAME
        ) ?: throw IllegalStateException("Failed to create $BACKUP_FOLDER_NAME directory")
    }

    private fun selectedAutoBackupDirectoryUri(): String? {
        val treeUriString = selectedBackupTreeUri() ?: return null
        return ensureAutoBackupDirectoryUri(Uri.parse(treeUriString)).toString()
    }

    private fun selectAutoBackupDirectory(result: MethodChannel.Result) {
        if (pendingBackupDirectoryResult != null) {
            result.error("REQUEST_ACTIVE", "A backup directory selection is already active", null)
            return
        }

        val treeIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                buildInitialTreeUri()?.let { initialUri ->
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
                }
            }
        }

        try {
            pendingBackupDirectoryResult = result
            startActivityForResult(treeIntent, SELECT_BACKUP_DIRECTORY_REQUEST)
        } catch (_: ActivityNotFoundException) {
            pendingBackupDirectoryResult = null
            result.error("NO_FILE_MANAGER", "No folder picker is available on this device", null)
        }
    }

    private fun saveAutoBackupFile(fileName: String, content: String): String {
        val treeUriString = selectedBackupTreeUri()
            ?: throw IllegalStateException("AutoBackup directory is not selected")
        val treeUri = Uri.parse(treeUriString)
        val parentUri = ensureAutoBackupDirectoryUri(treeUri)
        val fileUri = DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            "application/octet-stream",
            fileName
        ) ?: throw IllegalStateException("Failed to create backup file")

        contentResolver.openOutputStream(fileUri, "wt")?.use { outputStream ->
            outputStream.write(content.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("Failed to open backup file for writing")

        return fileUri.toString()
    }

    private fun listAutoBackupFiles(): List<Map<String, Any>> {
        val treeUriString = selectedBackupTreeUri() ?: return emptyList()
        val treeUri = Uri.parse(treeUriString)
        val directoryUri = ensureAutoBackupDirectoryUri(treeUri)
        val directoryId = DocumentsContract.getDocumentId(directoryUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, directoryId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        val files = mutableListOf<Map<String, Any>>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val modifiedIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                if (cursor.getString(mimeIndex) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                val documentId = cursor.getString(idIndex)
                files.add(
                    mapOf(
                        "name" to (cursor.getString(nameIndex) ?: ""),
                        "uri" to DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId).toString(),
                        "size" to (if (cursor.isNull(sizeIndex)) 0L else cursor.getLong(sizeIndex)),
                        "modified" to (if (cursor.isNull(modifiedIndex)) 0L else cursor.getLong(modifiedIndex))
                    )
                )
            }
        }
        return files
    }

    private fun openSelectedAutoBackupDirectory() {
        val backupDirectoryUri = selectedAutoBackupDirectoryUri()
            ?: throw IllegalStateException("AutoBackup directory is not selected")
        val uri = Uri.parse(backupDirectoryUri)

        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(viewIntent)
            return
        } catch (_: ActivityNotFoundException) {
            // Fall back to DocumentsUI with the backup directory as initial location.
        }

        val treeIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
            }
        }
        startActivity(treeIntent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SELECT_BACKUP_DIRECTORY_REQUEST) {
            val pendingResult = pendingBackupDirectoryResult
            pendingBackupDirectoryResult = null
            if (pendingResult == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pendingResult.success(null)
                return
            }

            val uri = data.data!!
            val flags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
                saveSelectedBackupTreeUri(uri)
                pendingResult.success(ensureAutoBackupDirectoryUri(uri).toString())
            } catch (e: Exception) {
                pendingResult.error("PERMISSION_ERROR", "Failed to persist backup directory permission: ${e.message}", null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeToUri" -> {
                    val uriString = call.argument<String>("uri")
                    val content = call.argument<String>("content")

                    if (uriString != null && content != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            contentResolver.openOutputStream(uri, "wt")?.use { outputStream ->
                                outputStream.write(content.toByteArray(Charsets.UTF_8))
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_ERROR", "Failed to write to URI: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "URI or content cannot be null", null)
                    }
                }
                "persistUriPermission" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "URI cannot be null or blank", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = Uri.parse(uriString)
                        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        contentResolver.takePersistableUriPermission(uri, flags)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", "Failed to persist URI permission: ${e.message}", null)
                    }
                }
                "selectAutoBackupDirectory" -> {
                    selectAutoBackupDirectory(result)
                }
                "getSelectedAutoBackupDirectory" -> {
                    try {
                        result.success(selectedAutoBackupDirectoryUri())
                    } catch (e: Exception) {
                        result.error("BACKUP_DIRECTORY_ERROR", "Failed to resolve backup directory: ${e.message}", null)
                    }
                }
                "openSelectedAutoBackupDirectory" -> {
                    try {
                        openSelectedAutoBackupDirectory()
                        result.success(true)
                    } catch (e: IllegalStateException) {
                        result.error("NO_BACKUP_DIRECTORY", e.message, null)
                    } catch (e: Exception) {
                        result.error("OPEN_DIRECTORY_ERROR", "Failed to open backup directory: ${e.message}", null)
                    }
                }
                "saveAutoBackupFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (fileName.isNullOrBlank() || content == null) {
                        result.error("INVALID_ARGS", "File name or content cannot be null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(saveAutoBackupFile(fileName, content))
                    } catch (e: IllegalStateException) {
                        result.error("NO_BACKUP_DIRECTORY", e.message, null)
                    } catch (e: Exception) {
                        result.error("WRITE_BACKUP_ERROR", "Failed to write backup file: ${e.message}", null)
                    }
                }
                "listAutoBackupFiles" -> {
                    try {
                        result.success(listAutoBackupFiles())
                    } catch (e: Exception) {
                        result.error("LIST_BACKUP_ERROR", "Failed to list backup files: ${e.message}", null)
                    }
                }
                "deleteAutoBackupFile" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Backup URI cannot be blank", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(DocumentsContract.deleteDocument(contentResolver, Uri.parse(uriString)))
                    } catch (e: Exception) {
                        result.error("DELETE_BACKUP_ERROR", "Failed to delete backup: ${e.message}", null)
                    }
                }
                "getAvailableBackupBytes" -> {
                    try {
                        result.success(StatFs(Environment.getExternalStorageDirectory().path).availableBytes)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

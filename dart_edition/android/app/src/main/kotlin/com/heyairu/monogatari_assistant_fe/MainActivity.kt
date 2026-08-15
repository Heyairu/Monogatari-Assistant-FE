package com.heyairu.monogatari_assistant_fe

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.heyairu.monogatari_assistant/file"
    private val P2P_CHANNEL = "com.heyairu.monogatari_assistant/p2p"
    private val BACKGROUND_EXECUTION_CHANNEL = "com.heyairu.monogatari_assistant/background_execution"
    private val SELECT_BACKUP_DIRECTORY_REQUEST = 4101
    private val LOCAL_NETWORK_PERMISSION_REQUEST = 4102
    private val SAVE_PROJECT_FILE_REQUEST = 4103
    private val BACKUP_PREFS = "monogatari_backup_preferences"
    private val BACKUP_TREE_URI_KEY = "auto_backup_tree_uri"
    private val BACKUP_FOLDER_NAME = "MonoAshi_Backup"
    private var pendingBackupDirectoryResult: MethodChannel.Result? = null
    private var pendingLocalNetworkPermissionResult: MethodChannel.Result? = null
    private var pendingProjectSaveResult: MethodChannel.Result? = null
    private var pendingProjectSaveContent: String? = null
    private val pendingExternalProjectUris = mutableListOf<String>()
    private var projectFileChannel: MethodChannel? = null
    private var dartIsReadyForProjectFiles = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enqueueExternalProjectIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enqueueExternalProjectIntent(intent)
    }

    private fun enqueueExternalProjectIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.scheme != "content" && uri.scheme != "file") return

        val uriString = uri.toString()
        val channel = projectFileChannel
        if (dartIsReadyForProjectFiles && channel != null) {
            channel.invokeMethod("openProjectFile", uriString)
        } else {
            pendingExternalProjectUris.add(uriString)
        }
    }

    private fun openExternalProjectUri(uriString: String): Map<String, String> {
        val uri = Uri.parse(uriString)
        val isFileUri = uri.scheme == "file"
        val name = if (isFileUri) {
            File(uri.path ?: "").name
        } else {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            } ?: uri.lastPathSegment
        } ?: "未命名.mnproj"
        val content = if (isFileUri) {
            File(uri.path ?: "").readText(Charsets.UTF_8)
        } else {
            contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: throw IOException("Document provider returned no input stream")
        }
        val grantedFlags = intent?.flags?.and(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        ) ?: 0
        if (grantedFlags != 0) {
            try {
                contentResolver.takePersistableUriPermission(uri, grantedFlags)
            } catch (_: SecurityException) {
                // Some providers deliberately grant one-time access only.
            }
        }
        return mapOf("name" to name, "uri" to uriString, "content" to content)
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestBatteryOptimizationExemption(result: MethodChannel.Result) {
        if (isBatteryOptimizationExempt()) {
            result.success(null)
            return
        }

        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            // Android displays and owns this consent prompt. The Dart side
            // rechecks the state when the app resumes rather than treating the
            // launch of the prompt as a grant.
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "BACKGROUND_PERMISSION_ERROR",
                "Failed to request background execution permission: ${error.message}",
                null
            )
        }
    }

    private fun saveProjectFile(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")?.trim()
        val content = call.argument<String>("content")
        if (fileName.isNullOrEmpty() || content == null) {
            result.error("INVALID_ARGS", "Project file name or content is invalid", null)
            return
        }
        if (pendingProjectSaveResult != null) {
            result.error("REQUEST_ACTIVE", "A project save request is already active", null)
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("NO_FILE_MANAGER", "No document provider can save project files", null)
            return
        }

        pendingProjectSaveResult = result
        pendingProjectSaveContent = content
        try {
            startActivityForResult(intent, SAVE_PROJECT_FILE_REQUEST)
        } catch (error: Exception) {
            pendingProjectSaveResult = null
            pendingProjectSaveContent = null
            result.error("SAVE_DIALOG_ERROR", "Failed to open project save dialog: ${error.message}", null)
        }
    }

    private class P2pNativeProbeException(
        val code: String,
        message: String,
        cause: Throwable? = null
    ) : Exception(message, cause)

    private fun ensureLocalNetworkPermission(result: MethodChannel.Result) {
        // This project currently targets SDK 36. Android 16 uses
        // NEARBY_WIFI_DEVICES only when Local Network Protection is enabled
        // through its compatibility flag. Other versions retain implicit LAN
        // access through INTERNET until the project targets SDK 37.
        if (Build.VERSION.SDK_INT != 36) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (pendingLocalNetworkPermissionResult != null) {
            result.error("REQUEST_ACTIVE", "A local network permission request is already active", null)
            return
        }

        pendingLocalNetworkPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES),
            LOCAL_NETWORK_PERMISSION_REQUEST
        )
    }

    private fun readBoundedProbeLine(socket: Socket, maxBytes: Int): String {
        val input = socket.getInputStream()
        val bytes = ByteArrayOutputStream()
        while (bytes.size() <= maxBytes) {
            val value = input.read()
            if (value < 0) {
                throw P2pNativeProbeException(
                    "INCOMPATIBLE_ENDPOINT",
                    "The peer closed before returning a complete P2P probe response"
                )
            }
            if (value == '\n'.code) {
                return bytes.toString(Charsets.UTF_8.name())
            }
            bytes.write(value)
        }
        throw P2pNativeProbeException(
            "INCOMPATIBLE_ENDPOINT",
            "The peer P2P probe response exceeded the size limit"
        )
    }

    private fun runWifiBoundLineExchange(
        host: String,
        port: Int,
        requestLine: String,
        maxResponseBytes: Int,
        connectTimeoutMillis: Int,
        readTimeoutMillis: Int
    ): String {
        if (requestLine.contains('\n') || requestLine.contains('\r') ||
            requestLine.toByteArray(Charsets.UTF_8).size > 65536
        ) {
            throw P2pNativeProbeException(
                "INVALID_REQUEST",
                "The P2P request line is invalid"
            )
        }
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val localNetworks = connectivityManager.allNetworks.filter { network ->
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true ||
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true
        }
        if (localNetworks.isEmpty()) {
            throw P2pNativeProbeException(
                "NO_LOCAL_NETWORK",
                "No active Wi-Fi or Ethernet network is available"
            )
        }

        var lastFailure: P2pNativeProbeException? = null
        for (network in localNetworks) {
            var responseStage = false
            try {
                Socket().use { socket ->
                    // Bind only this P2P socket. Other application traffic keeps
                    // its normal route and remains unaffected by VPN/cellular state.
                    network.bindSocket(socket)
                    socket.tcpNoDelay = true
                    socket.connect(
                        InetSocketAddress(host, port),
                        connectTimeoutMillis
                    )
                    responseStage = true
                    socket.soTimeout = readTimeoutMillis
                    val output = socket.getOutputStream()
                    output.write("$requestLine\n".toByteArray(Charsets.UTF_8))
                    output.flush()
                    return readBoundedProbeLine(socket, maxResponseBytes)
                }
            } catch (error: P2pNativeProbeException) {
                if (error.code == "INCOMPATIBLE_ENDPOINT") throw error
                lastFailure = error
            } catch (error: SocketTimeoutException) {
                lastFailure = P2pNativeProbeException(
                    if (responseStage) "RESPONSE_TIMEOUT" else "CONNECT_TIMEOUT",
                    if (responseStage) {
                        "TCP connected over Wi-Fi, but the peer did not answer the P2P probe"
                    } else {
                        "TCP could not connect over the active Wi-Fi network"
                    },
                    error
                )
            } catch (error: IOException) {
                lastFailure = P2pNativeProbeException(
                    if (responseStage) "RESPONSE_FAILED" else "CONNECT_FAILED",
                    if (responseStage) {
                        "The Wi-Fi P2P probe failed while reading the peer response"
                    } else {
                        "TCP could not connect over the active Wi-Fi network"
                    },
                    error
                )
            }
        }

        throw lastFailure ?: P2pNativeProbeException(
            "CONNECT_FAILED",
            "TCP could not connect over any active local network"
        )
    }

    private fun runWifiBoundLineExchanges(
        host: String,
        port: Int,
        requestLines: List<String>,
        maxResponseBytes: Int,
        connectTimeoutMillis: Int,
        readTimeoutMillis: Int
    ): List<String> {
        if (requestLines.isEmpty() || requestLines.size > 32 ||
            requestLines.any { requestLine ->
                requestLine.contains('\n') || requestLine.contains('\r') ||
                    requestLine.toByteArray(Charsets.UTF_8).size > 65536
            }
        ) {
            throw P2pNativeProbeException(
                "INVALID_REQUEST",
                "The P2P request line batch is invalid"
            )
        }
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val localNetworks = connectivityManager.allNetworks.filter { network ->
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true ||
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true
        }
        if (localNetworks.isEmpty()) {
            throw P2pNativeProbeException(
                "NO_LOCAL_NETWORK",
                "No active Wi-Fi or Ethernet network is available"
            )
        }

        var lastFailure: P2pNativeProbeException? = null
        for (network in localNetworks) {
            var responseStage = false
            try {
                Socket().use { socket ->
                    network.bindSocket(socket)
                    socket.tcpNoDelay = true
                    socket.connect(
                        InetSocketAddress(host, port),
                        connectTimeoutMillis
                    )
                    responseStage = true
                    socket.soTimeout = readTimeoutMillis
                    val output = socket.getOutputStream()
                    val responses = ArrayList<String>(requestLines.size)
                    for (requestLine in requestLines) {
                        output.write("$requestLine\n".toByteArray(Charsets.UTF_8))
                        output.flush()
                        responses.add(readBoundedProbeLine(socket, maxResponseBytes))
                    }
                    return responses
                }
            } catch (error: P2pNativeProbeException) {
                if (error.code == "INCOMPATIBLE_ENDPOINT") throw error
                lastFailure = error
            } catch (error: SocketTimeoutException) {
                val failure = P2pNativeProbeException(
                    if (responseStage) "RESPONSE_TIMEOUT" else "CONNECT_TIMEOUT",
                    if (responseStage) {
                        "TCP connected over Wi-Fi, but the peer did not answer the P2P exchange"
                    } else {
                        "TCP could not connect over the active Wi-Fi network"
                    },
                    error
                )
                if (responseStage) throw failure
                lastFailure = failure
            } catch (error: IOException) {
                val failure = P2pNativeProbeException(
                    if (responseStage) "RESPONSE_FAILED" else "CONNECT_FAILED",
                    if (responseStage) {
                        "The Wi-Fi P2P exchange failed while reading the peer response"
                    } else {
                        "TCP could not connect over the active Wi-Fi network"
                    },
                    error
                )
                if (responseStage) throw failure
                lastFailure = failure
            }
        }

        throw lastFailure ?: P2pNativeProbeException(
            "CONNECT_FAILED",
            "TCP could not connect over any active local network"
        )
    }

    private fun runWifiBoundProbe(
        host: String,
        port: Int,
        connectTimeoutMillis: Int,
        readTimeoutMillis: Int
    ) {
        val response = runWifiBoundLineExchange(
            host,
            port,
            "MONOGATARI_P2P_PROBE/1",
            128,
            connectTimeoutMillis,
            readTimeoutMillis
        )
        if (response != "MONOGATARI_P2P_REACHABLE/1") {
            throw P2pNativeProbeException(
                "INCOMPATIBLE_ENDPOINT",
                "The target is not a compatible Monogatari Assistant P2P endpoint"
            )
        }
    }

    private fun probeWifiEndpoint(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port")
        val connectTimeoutMillis = call.argument<Int>("connectTimeoutMillis") ?: 8000
        val readTimeoutMillis = call.argument<Int>("readTimeoutMillis") ?: 8000
        if (host.isNullOrBlank() || port == null || port !in 1..65535) {
            result.error("INVALID_ENDPOINT", "Host or port is invalid", null)
            return
        }

        thread(name = "P2pWifiProbe") {
            try {
                runWifiBoundProbe(host, port, connectTimeoutMillis, readTimeoutMillis)
                runOnUiThread { result.success(true) }
            } catch (error: P2pNativeProbeException) {
                runOnUiThread { result.error(error.code, error.message, null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "NATIVE_PROBE_FAILED",
                        error.message ?: "Android Wi-Fi P2P probe failed",
                        null
                    )
                }
            }
        }
    }

    private fun exchangeWifiLine(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port")
        val requestLine = call.argument<String>("requestLine")
        val maxResponseBytes = call.argument<Int>("maxResponseBytes") ?: 2048
        val connectTimeoutMillis = call.argument<Int>("connectTimeoutMillis") ?: 8000
        val readTimeoutMillis = call.argument<Int>("readTimeoutMillis") ?: 8000
        if (host.isNullOrBlank() || port == null || port !in 1..65535 ||
            requestLine.isNullOrEmpty() || maxResponseBytes !in 1..65536
        ) {
            result.error("INVALID_ENDPOINT", "Wi-Fi line exchange arguments are invalid", null)
            return
        }

        thread(name = "P2pWifiExchange") {
            try {
                val response = runWifiBoundLineExchange(
                    host,
                    port,
                    requestLine,
                    maxResponseBytes,
                    connectTimeoutMillis,
                    readTimeoutMillis
                )
                runOnUiThread { result.success(response) }
            } catch (error: P2pNativeProbeException) {
                runOnUiThread { result.error(error.code, error.message, null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "NATIVE_EXCHANGE_FAILED",
                        error.message ?: "Android Wi-Fi P2P exchange failed",
                        null
                    )
                }
            }
        }
    }

    private fun exchangeWifiLines(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port")
        val requestLines = call.argument<List<String>>("requestLines")
        val maxResponseBytes = call.argument<Int>("maxResponseBytes") ?: 2048
        val connectTimeoutMillis = call.argument<Int>("connectTimeoutMillis") ?: 8000
        val readTimeoutMillis = call.argument<Int>("readTimeoutMillis") ?: 8000
        if (host.isNullOrBlank() || port == null || port !in 1..65535 ||
            requestLines.isNullOrEmpty() || requestLines.size > 32 ||
            maxResponseBytes !in 1..65536
        ) {
            result.error("INVALID_ENDPOINT", "Wi-Fi line exchange arguments are invalid", null)
            return
        }

        thread(name = "P2pWifiBatchExchange") {
            try {
                val responses = runWifiBoundLineExchanges(
                    host,
                    port,
                    requestLines,
                    maxResponseBytes,
                    connectTimeoutMillis,
                    readTimeoutMillis
                )
                runOnUiThread { result.success(responses) }
            } catch (error: P2pNativeProbeException) {
                runOnUiThread { result.error(error.code, error.message, null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "NATIVE_EXCHANGE_FAILED",
                        error.message ?: "Android Wi-Fi P2P batch exchange failed",
                        null
                    )
                }
            }
        }
    }

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
        if (requestCode == SAVE_PROJECT_FILE_REQUEST) {
            val pendingResult = pendingProjectSaveResult
            val content = pendingProjectSaveContent
            pendingProjectSaveResult = null
            pendingProjectSaveContent = null
            if (pendingResult == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pendingResult.success(null)
                return
            }

            val uri = data.data!!
            val permissionFlags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            try {
                if (permissionFlags == 0) {
                    throw SecurityException("Document provider did not grant persistent read/write access")
                }
                contentResolver.takePersistableUriPermission(uri, permissionFlags)
                val outputStream = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IOException("Document provider returned no output stream")
                outputStream.use {
                    it.write((content ?: "").toByteArray(Charsets.UTF_8))
                    it.flush()
                }
                pendingResult.success(uri.toString())
            } catch (error: Exception) {
                pendingResult.error("SAVE_PROJECT_ERROR", "Failed to persist project file: ${error.message}", null)
            }
            return
        }

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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == LOCAL_NETWORK_PERMISSION_REQUEST) {
            val pendingResult = pendingLocalNetworkPermissionResult
            pendingLocalNetworkPermissionResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            return
        }

        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_EXECUTION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationExempt" -> result.success(isBatteryOptimizationExempt())
                "requestBatteryOptimizationExemption" -> requestBatteryOptimizationExemption(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, P2P_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureLocalNetworkPermission" -> ensureLocalNetworkPermission(result)
                "probeWifiEndpoint" -> probeWifiEndpoint(call, result)
                "exchangeWifiLine" -> exchangeWifiLine(call, result)
                "exchangeWifiLines" -> exchangeWifiLines(call, result)
                else -> result.notImplemented()
            }
        }
        projectFileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        projectFileChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingProjectFiles" -> {
                    dartIsReadyForProjectFiles = true
                    result.success(pendingExternalProjectUris.toList())
                    pendingExternalProjectUris.clear()
                }
                "openExternalProjectUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Project URI cannot be null or blank", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(openExternalProjectUri(uriString))
                    } catch (e: Exception) {
                        result.error("OPEN_PROJECT_ERROR", "Failed to read project file: ${e.message}", null)
                    }
                }
                "writeToUri" -> {
                    val uriString = call.argument<String>("uri")
                    val content = call.argument<String>("content")

                    if (uriString != null && content != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            val outputStream = contentResolver.openOutputStream(uri, "wt")
                                ?: throw IOException("Document provider returned no output stream")
                            outputStream.use {
                                outputStream.write(content.toByteArray(Charsets.UTF_8))
                                outputStream.flush()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_ERROR", "Failed to write to URI: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "URI or content cannot be null", null)
                    }
                }
                "saveProjectFile" -> saveProjectFile(call, result)
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

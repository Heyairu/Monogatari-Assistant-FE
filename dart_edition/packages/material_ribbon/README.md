# Material Ribbon: MonoAshi layout patch

Vendored from `Heyairu/flutter_material_ribbon`, version 1.3.0, commit
`29833e0dbd4126e289b56119100ad1aefb648291`.

Upstream: https://github.com/Heyairu/flutter_material_ribbon

The only source change stretches the main `MaterialRibbon` column across the
available width. This gives the horizontal command viewport the full width and
keeps short command groups left-aligned instead of centering the entire surface.
The package has no public option for this alignment in the pinned version.

The Dart sources, pubspec, and BSD-3-Clause license otherwise match upstream.
When updating, reapply or remove this patch and run MonoAshi's
`test/toolbar_modes_widget_test.dart` and `test/editor_toolbar_quill_test.dart`.

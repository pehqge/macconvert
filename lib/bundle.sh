#!/bin/zsh
# bundle.sh — generates .workflow bundles programmatically (no Automator GUI).
#
# A Quick Action is a .workflow bundle with two plists:
#   Contents/Info.plist     — NSServices registration: which UTIs trigger it,
#                             the menu label, and the Finder-only context.
#   Contents/document.wflow — an Automator document with a single
#                             "Run Shell Script" action that execs our script.
#
# Both plists mirror what Automator itself writes when saving a Quick Action.
# That fidelity matters: bundles with a CFBundleIdentifier or without
# NSIconName/NSBackgroundColorName get filed under the legacy "Services"
# submenu instead of "Quick Actions" in Finder's right-click menu.

# mc_bundle_write <bundle-name> <utis-csv> <script-path> <dest-dir> <menu-label>
#
# Writes <dest-dir>/<bundle-name>.workflow. The on-disk name keeps the
# "MacConvert - " prefix so uninstall can find our bundles by pattern; the
# menu label drops it for a cleaner right-click menu.
mc_bundle_write() {
  local name="$1" utis_csv="$2" script_path="$3" dest_dir="$4" display_name="$5"

  local workflow_dir="${dest_dir}/${name}.workflow"
  local contents_dir="${workflow_dir}/Contents"

  # Idempotent: blow away any prior version, then recreate.
  rm -rf "${workflow_dir}"
  mkdir -p "${contents_dir}"

  # The menu icon travels inside document.wflow as base64 image data, exactly
  # like Automator's "custom image" option.
  local icon_data="" icon_xml=""
  if [[ -f "${MC_RESOURCES_DIR}/icon-menu.png" ]]; then
    icon_data="$(/usr/bin/base64 -b 52 -i "${MC_RESOURCES_DIR}/icon-menu.png")"
    icon_xml="    <key>customImageFileData</key>
    <data>
${icon_data}
    </data>
    <key>customImageFileExtension</key>
    <string>png</string>
"
  fi

  local send_types_xml="" u
  for u in "${(@s:,:)utis_csv}"; do
    send_types_xml+="                <string>${u}</string>"$'\n'
  done

  cat > "${contents_dir}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSBackgroundColorName</key>
            <string>background</string>
            <key>NSIconName</key>
            <string>workflowCustomImageTemplate</string>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>${display_name}</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSApplicationIdentifier</key>
                <string>com.apple.finder</string>
            </dict>
            <key>NSSendFileTypes</key>
            <array>
${send_types_xml}            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

  # Escape the script path for plist embedding.
  local esc_script="${script_path//&/&amp;}"
  esc_script="${esc_script//</&lt;}"
  esc_script="${esc_script//>/&gt;}"

  cat > "${contents_dir}/document.wflow" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>
                    <key>CheckedForUserDefaultShell</key>
                    <dict/>
                    <key>inputMethod</key>
                    <dict/>
                    <key>shell</key>
                    <dict/>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>"${esc_script}" "\$@"</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/zsh</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>BA1F0DCB-1111-4444-8888-000000000001</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                </array>
                <key>OutputUUID</key>
                <string>BA1F0DCB-1111-4444-8888-000000000002</string>
                <key>UUID</key>
                <string>BA1F0DCB-1111-4444-8888-000000000003</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict/>
                <key>conversionLabel</key>
                <integer>0</integer>
                <key>isViewVisible</key>
                <integer>1</integer>
                <key>location</key>
                <string>100.000000:316.000000</string>
                <key>nibPath</key>
                <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
            </dict>
            <key>isViewVisible</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>applicationBundleID</key>
        <string>com.apple.finder</string>
        <key>applicationBundleIDsByPath</key>
        <dict>
            <key>/System/Library/CoreServices/Finder.app</key>
            <string>com.apple.finder</string>
        </dict>
        <key>applicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>
        <key>applicationPaths</key>
        <array>
            <string>/System/Library/CoreServices/Finder.app</string>
        </array>
        <key>backgroundColorName</key>
        <string>background</string>
${icon_xml}        <key>inputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>outputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>presentationMode</key>
        <integer>15</integer>
        <key>processesInput</key>
        <false/>
        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>
        <key>serviceApplicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <false/>
        <key>useAutomaticInputType</key>
        <false/>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
EOF

  # A malformed plist would register a broken Service — validate both.
  if ! /usr/bin/plutil -lint "${contents_dir}/Info.plist" >/dev/null \
     || ! /usr/bin/plutil -lint "${contents_dir}/document.wflow" >/dev/null; then
    rm -rf "${workflow_dir}"
    mc_error "generated plist failed validation for ${name}"
    return 1
  fi
}

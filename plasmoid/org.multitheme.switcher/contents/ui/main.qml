import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Das Skript liegt im Widget-Paket selbst – keine separate Installation nötig
    readonly property string tool: "python3 " + quote(decodeURIComponent(
        Qt.resolvedUrl("../code/multitheme").toString().replace(/^file:\/\//, "")))

    property var worlds: []
    property string activeWorld: ""
    property string busyText: ""

    Plasmoid.icon: "preferences-desktop-theme-global"
    toolTipMainText: "Multitheme"
    toolTipSubText: activeWorld ? "Aktive Welt: " + activeWorld : "Noch keine Welt angelegt"

    function quote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    // ---- Befehle ausführen ------------------------------------------------

    property var callbacks: ({})

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = root.callbacks[source]
            delete root.callbacks[source]
            disconnectSource(source)
            if (cb) {
                cb(data["exit code"], data["stdout"], data["stderr"])
            }
        }
    }

    function exec(cmd, cb) {
        // Gleiche Befehle direkt hintereinander würden sonst zusammengelegt
        const source = cmd + " #" + Date.now() + Math.random()
        callbacks[source] = cb || null
        executable.connectSource(source)
    }

    // Wechseln/Anlegen startet die Plasma-Shell neu – und damit auch dieses
    // Widget. Darum außerhalb der Shell laufen lassen.
    function detached(args, text) {
        busyText = text
        const cmd = tool + " " + args
        // Ohne systemd-Benutzersitzung reicht eine eigene Sitzung
        exec("systemd-run --user --collect --quiet " + cmd + " || setsid -f " + cmd + " >/dev/null 2>&1")
    }

    function refresh() {
        exec(tool + " list", (code, out) => {
            const list = []
            let active = ""
            for (const line of out.split("\n")) {
                if (!line.trim()) continue
                const name = line.substring(2)
                if (line.startsWith("* ")) active = name
                list.push(name)
            }
            worlds = list
            activeWorld = active
        })
    }

    function switchTo(name) {
        if (name === activeWorld || busyText) return
        detached("switch " + quote(name), "Wechsle zu „" + name + "“ …")
    }

    function create(name, fresh) {
        name = name.trim()
        if (!name || busyText) return
        if (worlds.length === 0) {
            // Erster Start: der jetzige Desktop wird zur ersten Welt
            detached("init " + quote(name), "Speichere aktuellen Desktop als „" + name + "“ …")
            return
        }
        detached("new " + quote(name) + (fresh ? " --frisch" : ""), "Lege „" + name + "“ an …")
    }

    function rename(oldName, newName) {
        newName = newName.trim()
        if (!newName || newName === oldName) return
        exec(tool + " rename " + quote(oldName) + " " + quote(newName), () => refresh())
    }

    Component.onCompleted: refresh()
    onExpandedChanged: if (root.expanded) refresh()

    // ---- Oberfläche -------------------------------------------------------

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: "Welten"
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refresh()
                    PlasmaComponents3.ToolTip { text: "Neu laden" }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    model: root.worlds
                    clip: true
                    spacing: Kirigami.Units.smallSpacing

                    delegate: PlasmaComponents3.ItemDelegate {
                        id: row
                        required property string modelData
                        readonly property bool active: modelData === root.activeWorld
                        property bool editing: false

                        width: ListView.view.width
                        highlighted: active
                        enabled: !root.busyText
                        onClicked: if (!editing) root.switchTo(modelData)

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: row.active ? "checkmark" : "preferences-desktop-theme-global"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }

                            PlasmaComponents3.Label {
                                visible: !row.editing
                                Layout.fillWidth: true
                                text: row.modelData
                                font.bold: row.active
                                elide: Text.ElideRight
                            }

                            PlasmaComponents3.TextField {
                                id: renameField
                                visible: row.editing
                                Layout.fillWidth: true
                                text: row.modelData
                                onAccepted: {
                                    root.rename(row.modelData, text)
                                    row.editing = false
                                }
                                Keys.onEscapePressed: row.editing = false
                            }

                            PlasmaComponents3.ToolButton {
                                icon.name: row.editing ? "dialog-ok-apply" : "edit-rename"
                                onClicked: {
                                    if (row.editing) {
                                        root.rename(row.modelData, renameField.text)
                                        row.editing = false
                                    } else {
                                        renameField.text = row.modelData
                                        row.editing = true
                                        renameField.forceActiveFocus()
                                        renameField.selectAll()
                                    }
                                }
                                PlasmaComponents3.ToolTip { text: row.editing ? "Übernehmen" : "Umbenennen" }
                            }
                        }
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        visible: list.count === 0
                        iconName: "preferences-desktop-theme-global"
                        text: "Noch keine Welten"
                        explanation: "Gib unten einen Namen ein – dein jetziger Desktop wird zur ersten Welt."
                    }
                }
            }

            PlasmaComponents3.Label {
                visible: root.busyText !== ""
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.busyText
                opacity: 0.8
            }

            Kirigami.Separator { Layout.fillWidth: true }

            PlasmaComponents3.TextField {
                id: newName
                Layout.fillWidth: true
                placeholderText: root.worlds.length ? "Name der neuen Welt" : "Name für deinen jetzigen Desktop"
                enabled: !root.busyText
                onAccepted: root.create(text, false)
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: root.worlds.length ? "edit-copy" : "document-save"
                    text: root.worlds.length ? "Kopie" : "Als erste Welt speichern"
                    enabled: newName.text.trim() !== "" && !root.busyText
                    onClicked: root.create(newName.text, false)
                    PlasmaComponents3.ToolTip {
                        text: root.worlds.length ? "Neue Welt als Kopie der aktuellen" : "Der jetzige Desktop wird deine erste Welt"
                    }
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    visible: root.worlds.length > 0
                    icon.name: "list-add"
                    text: "Frisch"
                    enabled: newName.text.trim() !== "" && !root.busyText
                    onClicked: root.create(newName.text, true)
                    PlasmaComponents3.ToolTip { text: "Neue Welt mit frischem Standard-Plasma" }
                }
            }
        }
    }
}

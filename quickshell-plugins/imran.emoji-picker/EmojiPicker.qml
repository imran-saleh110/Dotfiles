import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Picker.js" as Picker

// Windows-style emoji picker with Facebook-style category order and
// popularity-based emoji ordering. Summoned with:
//   omarchy-shell shell summon imran.emoji-picker
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "imran.emoji-picker"
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string dataPath: pluginDir + "/data/emojis.json"
  readonly property string insertHelper: omarchyPath + "/bin/omarchy-menu-emoji-insert"

  property bool opened: false
  property string filterText: ""
  property var categories: []
  property var categoryStarts: ({})
  property var displayCategories: []
  property int selectedIndex: 0
  property var activeCategory: -1

  property int pointerX: 0
  property int pointerY: 0
  property int cardX: 0
  property int cardY: 0
  property int cardWidth: 350
  property int cardHeight: 420

  // emoji-mart dark palette.
  readonly property color background: "#151617"
  readonly property color inputBackground: "#2b2e31"
  readonly property color foreground: "#dededd"
  readonly property color muted: "#8b8c8c"
  readonly property color accent: "#3a82f7"
  readonly property color hover: "#2b2e32"
  readonly property color divider: Qt.rgba(1, 1, 1, 0.1)
  readonly property string emojiFont: "Noto Color Emoji"
  readonly property string iconFont: "JetBrainsMono Nerd Font"
  readonly property int cellSize: 38
  readonly property int gridColumns: Math.max(1, Math.floor(emojiGrid.width / cellSize))
  readonly property real gridCellWidth: emojiGrid.width / gridColumns

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  FileView {
    id: dataView
    path: root.dataPath
    onLoaded: root.loadData(text())
    onLoadFailed: console.warn("emoji picker: could not read", path)
  }

  Process {
    id: cursorProcess
    command: ["hyprctl", "-j", "cursorpos"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        try {
          var pos = JSON.parse(text)
          if (typeof pos.x === "number" && typeof pos.y === "number") root.applyCursor(pos.x, pos.y)
        } catch (e) {
          // Keep the centered fallback when the compositor cannot be queried.
        }
      }
    }
  }

  ListModel { id: flatModel }

  function open(payloadJson) {
    var args = {}
    try { args = JSON.parse(payloadJson || "{}") || {} } catch (e) { args = {} }

    root.filterText = ""
    root.selectedIndex = 0
    root.activeCategory = root.categories.length ? root.categories[0].id : -1
    searchInput.text = ""
    // The text field is blank, but the model still holds the last search's
    // results until it is rebuilt here.
    root.rebuild()
    root.opened = true
    root.centreCard()

    if (typeof args.x === "number" && typeof args.y === "number") root.applyCursor(args.x, args.y)
    else if (!cursorProcess.running) cursorProcess.running = true

    Qt.callLater(function() {
      emojiGrid.contentY = 0
      searchInput.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  // Scripting hooks: omarchy-shell shell call imran.emoji-picker search 'smile'
  function search(query: string): string {
    searchInput.text = query
    root.setFilter(query)
    return String(flatModel.count)
  }

  // Scripting hooks: omarchy-shell shell call imran.emoji-picker jump flags
  function jump(id: string): string {
    root.jumpToCategory(id)
    return String(root.categoryStarts[id])
  }

  // Small introspection hook for `omarchy-shell shell call imran.emoji-picker state`.
  function state(): string {
    return JSON.stringify({
      opened: root.opened,
      categories: root.categories.length,
      emojis: flatModel.count,
      filter: root.filterText,
      field: searchInput.text,
      active: root.activeCategory,
      navItemWidth: navRow.width > 0 ? (navRow.width - (root.categories.length - 1) * navRow.spacing) / root.categories.length : 0,
      gridColumns: root.gridColumns,
      gridCellWidth: root.gridCellWidth,
      contentY: emojiGrid.contentY,
      x: root.cardX,
      y: root.cardY,
      width: root.cardWidth,
      height: root.cardHeight
    })
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadData(raw) {
    root.categories = Picker.parse(raw)
    root.rebuild()
  }

  function rebuild() {
    var visible = Picker.filter(root.categories, root.filterText, 3000)
    var starts = {}
    var sections = []
    flatModel.clear()

    for (var c = 0; c < visible.length; c++) {
      var cat = visible[c]
      starts[cat.id] = flatModel.count
      sections.push({ id: cat.id, name: cat.name, icon: cat.icon, start: flatModel.count, emojis: cat.emojis })
      for (var i = 0; i < cat.emojis.length; i++) {
        var item = cat.emojis[i]
        flatModel.append({
          e: item.e, n: item.n, c: item.c, k: item.k,
          cat: cat.name, catId: cat.id
        })
      }
    }
    root.categoryStarts = starts
    root.displayCategories = sections
    if (root.selectedIndex >= flatModel.count) root.selectedIndex = Math.max(0, flatModel.count - 1)
    if (root.selectedIndex < 0) root.selectedIndex = 0
  }

  function clampScroll(y) {
    var maxY = Math.max(0, emojiGrid.contentHeight - emojiGrid.height)
    return Math.max(0, Math.min(y, maxY))
  }

  // Calculate a cell's position from the section layout. Tracking delegates in
  // a map races with Repeater destruction on every rebuild; the math cannot.
  function geometryFor(index) {
    var columns = root.gridColumns
    var y = 0
    for (var c = 0; c < root.displayCategories.length; c++) {
      var cat = root.displayCategories[c]
      var count = cat.emojis.length
      var rows = Math.ceil(count / columns)
      if (index >= cat.start && index < cat.start + count) {
        var local = index - cat.start
        return {
          y: y + 26 + Math.floor(local / columns) * root.cellSize,
          height: root.cellSize
        }
      }
      y += 26 + rows * root.cellSize
    }
    return null
  }

  // Flickable has no ensureVisible() (that is a ListView/GridView method).
  function ensureVisible(index, alignTop) {
    var g = root.geometryFor(index)
    if (!g) return
    if (alignTop) {
      emojiGrid.contentY = clampScroll(g.y - 26) // keep the category header visible
      return
    }
    var top = emojiGrid.contentY
    var bottom = top + emojiGrid.height
    if (g.y < top) emojiGrid.contentY = clampScroll(g.y)
    else if (g.y + g.height > bottom) emojiGrid.contentY = clampScroll(g.y + g.height - emojiGrid.height)
  }

  function setFilter(value) {
    root.filterText = value
    root.selectedIndex = 0
    root.activeCategory = -1
    root.rebuild()
  }

  function select(index) {
    if (flatModel.count === 0) return
    root.selectedIndex = (index + flatModel.count) % flatModel.count
    root.ensureVisible(root.selectedIndex)
  }

  function selectRow(delta) {
    root.select(root.selectedIndex + delta * root.gridColumns)
  }

  function selectPage(delta) {
    var rows = Math.max(1, Math.floor(emojiGrid.height / root.cellSize))
    root.select(root.selectedIndex + delta * root.gridColumns * rows)
  }

  function jumpToCategory(id) {
    if (root.filterText) {
      searchInput.text = ""
      root.setFilter("")
    }
    var index = root.categoryStarts[id]
    root.activeCategory = index === undefined ? -1 : id
    if (index !== undefined) {
      root.selectedIndex = index
      Qt.callLater(function() { root.ensureVisible(index, true) })
    }
  }

  function activateIndex(index, copyOnly) {
    if (index < 0 || index >= flatModel.count) return
    var item = flatModel.get(index)
    var value = item.e
    root.dismiss()
    if (copyOnly) {
      Quickshell.execDetached(["bash", "-lc", 'printf %s "$1" | wl-copy --type text/plain --sensitive', "bash", value])
    } else {
      Quickshell.execDetached([root.insertHelper, value])
    }
  }

  function monitorAt(x, y) {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      if (x >= m.x && x < m.x + m.width && y >= m.y && y < m.y + m.height) return m
    }
    return Hyprland.focusedMonitor || (monitors.length ? monitors[0] : null)
  }

  function screenFor(name) {
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
    }
    return null
  }

  function place(x, y) {
    root.pointerX = x
    root.pointerY = y
    var m = root.monitorAt(x, y)
    if (m) {
      var screen = root.screenFor(String(m.name))
      if (screen) window.targetScreen = screen
    }

    var width = Quickshell.screens.length ? Quickshell.screens[0].width : 1920
    var height = Quickshell.screens.length ? Quickshell.screens[0].height : 1080
    if (m) {
      width = m.width
      height = m.height
      root.cardWidth = Math.min(350, width - 16)
      root.cardHeight = Math.min(420, height - 16)
      var localX = x - m.x
      var localY = y - m.y
      var px = Math.max(8, Math.min(localX, width - root.cardWidth - 8))
      var py = localY + 18
      if (py + root.cardHeight > height - 8) py = localY - root.cardHeight - 14
      py = Math.max(8, Math.min(py, height - root.cardHeight - 8))
      root.cardX = px
      root.cardY = py
      return
    }

    root.cardWidth = Math.min(350, width - 16)
    root.cardHeight = Math.min(420, height - 16)
    root.cardX = Math.max(8, (width - root.cardWidth) / 2)
    root.cardY = Math.max(8, Math.min(y + 18, height - root.cardHeight - 8))
  }

  function applyCursor(x, y) {
    if (!root.opened) return
    root.place(x, y)
  }

  function centreCard() {
    var m = Hyprland.focusedMonitor
    if (m) root.place(m.x + Math.floor(m.width / 2), m.y + Math.floor(m.height / 2))
    else root.place(0, 0)
  }

  OverlayWindow {
    id: window
    shown: root.opened
    shownLayer: WlrLayer.Overlay
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "imran-emoji-picker"

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    // Soft drop shadow, matching emoji-mart's subtle card shadow.
    Rectangle {
      x: root.cardX + 2
      y: root.cardY + 3
      width: root.cardWidth
      height: root.cardHeight
      radius: 10
      color: "#000000"
      opacity: 0.4
      visible: root.opened
      z: 1
    }

    Rectangle {
      id: card
      x: root.cardX
      y: root.cardY
      width: root.cardWidth
      height: root.cardHeight
      radius: 10
      color: root.background
      border.width: 1
      border.color: root.divider
      clip: true
      z: 2
      visible: root.opened

      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.97
      Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      Behavior on scale {
        NumberAnimation {
          duration: Style.duration(120)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Search row: emoji-mart's 10px-radius search field with loupe + clear.
        Rectangle {
          width: parent.width
          height: 38
          radius: 10
          color: searchInput.activeFocus ? "#000000" : root.inputBackground
          border.width: searchInput.activeFocus ? 1 : 0
          border.color: root.accent

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf002"
            textFormat: Text.PlainText
            font.family: root.iconFont
            font.pixelSize: 14
            color: root.muted
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: strings.t("picker.search")
            textFormat: Text.PlainText
            color: root.muted
            opacity: 0.65
            font.family: Style.font.family
            font.pixelSize: 14
            visible: searchInput.text.length === 0
          }

          FilterInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: clearButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: navKeys
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: 14
            onTextChanged: if (text !== root.filterText) root.setFilter(text)
          }

          Text {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf00d"
            textFormat: Text.PlainText
            font.family: root.iconFont
            font.pixelSize: 12
            color: root.muted
            visible: searchInput.text.length > 0

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              onClicked: {
                searchInput.text = ""
                root.setFilter("")
                searchInput.forceActiveFocus()
              }
            }
          }
        }

        // Category strip, styled after emoji-mart's icon nav + accent underline.
        Rectangle {
          width: parent.width
          height: 30
          color: "transparent"

          Row {
            id: navRow
            anchors.fill: parent
            spacing: 2

            Repeater {
              model: root.categories

              Item {
                width: (navRow.width - (root.categories.length - 1) * navRow.spacing) / root.categories.length
                height: 30

                property bool isActive: root.activeCategory === modelData.id

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: parent.isActive ? root.hover : "transparent"
                  opacity: parent.isActive ? 0.7 : 1
                  Behavior on opacity { NumberAnimation { duration: Style.duration(125) } }
                }

                Text {
                  anchors.centerIn: parent
                  text: modelData.icon
                  textFormat: Text.PlainText
                  font.family: root.emojiFont
                  font.pixelSize: 18
                  color: parent.isActive ? root.accent : root.muted
                  opacity: parent.isActive ? 1 : 0.72
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 3
                  radius: 2
                  color: root.accent
                  visible: parent.isActive
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.jumpToCategory(modelData.id)
                }
              }
            }
          }
        }

        // Emoji grid with emoji-mart style category headings.
        Flickable {
          id: emojiGrid
          width: parent.width
          height: Math.max(0, parent.height - 38 - 30 - 16)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentWidth: width
          contentHeight: sectionsColumn.implicitHeight

          Column {
            id: sectionsColumn
            width: emojiGrid.width

            Repeater {
              model: root.displayCategories

              Column {
                width: parent.width
                property int baseIndex: modelData.start

                Rectangle {
                  width: parent.width
                  height: 26
                  color: root.background

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    textFormat: Text.PlainText
                    color: root.muted
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                  }
                }

                Grid {
                  width: parent.width
                  columns: root.gridColumns

                  Repeater {
                    model: modelData.emojis

                    Item {
                      property int itemIndex: baseIndex + index
                      property string glyph: modelData.e

                      width: root.gridCellWidth
                      height: root.cellSize

                      Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 6
                        color: root.selectedIndex === parent.itemIndex ? root.hover : "transparent"
                      }

                      Text {
                        anchors.centerIn: parent
                        text: parent.glyph
                        textFormat: Text.PlainText
                        font.family: root.emojiFont
                        font.pixelSize: 25
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = parent.itemIndex
                        onClicked: root.activateIndex(parent.itemIndex, mouse.modifiers & Qt.ShiftModifier)
                      }
                    }
                  }
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: flatModel.count === 0 && searchInput.text.length > 0
            text: strings.t("picker.noResults")
            textFormat: Text.PlainText
            color: root.muted
            font.family: Style.font.family
            font.pixelSize: 14
          }
        }
      }

      Item {
        id: navKeys
        anchors.fill: parent
        focus: false

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) {
              searchInput.text = ""
              root.setFilter("")
            } else {
              root.dismiss()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectRow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectRow(1)
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Left) {
            root.select(-1)
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Right) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.select(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.select(flatModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateIndex(root.selectedIndex, !!(event.modifiers & Qt.ShiftModifier))
            event.accepted = true
          }
        }
      }
    }
  }
}

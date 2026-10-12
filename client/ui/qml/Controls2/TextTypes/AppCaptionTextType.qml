import QtQuick

import Style 1.0

Text {
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    lineHeight: 14
    lineHeightMode: Text.FixedHeight

    color: AmneziaStyle.color.textPrimary
    font.pixelSize: 12
    font.weight: 400
    font.family: "PT Root UI VF"
    font.letterSpacing: 0

    wrapMode: Text.WordWrap
}

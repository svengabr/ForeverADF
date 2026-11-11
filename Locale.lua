-- English strings are the keys; other languages override them below.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

if GetLocale() ~= "deDE" then return end

-- Frame
L["Lit: on the target. Dark: missing."] = "Hell: auf dem Ziel. Dunkel: fehlt."
L["Shift + drag: move"] = "Umschalt + Ziehen: verschieben"
L["This client has no aura container; the icons cannot light up."] = "Dieser Client hat keinen Aura-Container; die Symbole können nicht aufleuchten."

-- Chat
L["Frame shown."] = "Anzeige eingeblendet."
L["Frame hidden. Type /adf show to bring it back."] = "Anzeige ausgeblendet. Mit /adf show holst du sie zurück."
L["Position reset."] = "Position zurückgesetzt."
L["Frame locked."] = "Anzeige gesperrt."
L["Frame unlocked. Hold Shift and drag to move it."] = "Anzeige entsperrt. Zum Verschieben Umschalt halten und ziehen."
L["Commands:"] = "Befehle:"
L["open the options"] = "Optionen öffnen"
L["show the frame"] = "Anzeige einblenden"
L["hide the frame"] = "Anzeige ausblenden"
L["lock or unlock the frame"] = "Anzeige sperren oder entsperren"
L["reset the position"] = "Position zurücksetzen"
L["Loaded. Type /adf for the options."] = "Geladen. /adf öffnet die Optionen."

-- Options
L["Options"] = "Optionen"
L["Display"] = "Anzeige"
L["Show the frame"] = "Anzeige einblenden"
L["Show remaining time"] = "Restzeit anzeigen"
L["Hide out of combat"] = "Außerhalb des Kampfes ausblenden"
L["Hide when not in a group"] = "Ohne Gruppe ausblenden"
L["Hide without a target"] = "Ohne Ziel ausblenden"
L["Lock position"] = "Position sperren"
L["Click-through"] = "Klicks durchlassen"
L["The frame ignores the mouse: no tooltips, no moving."] = "Die Anzeige ignoriert die Maus: keine Tooltips, kein Verschieben."
L["Icon size"] = "Symbolgröße"
L["Icons per row"] = "Symbole pro Reihe"
L["Tracked debuffs"] = "Verfolgte Debuffs"
L["Add your own debuff"] = "Eigenen Debuff hinzufügen"
L["Enter the spell ID of the debuff. The game shows it only by its ID in combat, so a name is not enough."] = "Gib die Zauber-ID des Debuffs ein. Im Kampf zeigt das Spiel ihn nur anhand der ID, ein Name reicht darum nicht."
L["Please enter a spell ID (a number)."] = "Bitte eine Zauber-ID (eine Zahl) eingeben."
L["Add"] = "Hinzufügen"
L["Added %s."] = "%s hinzugefügt."
L["Removed %s."] = "%s entfernt."
L["%s is already in the list."] = "%s steht schon in der Liste."
L["There is no spell with ID %d in this client."] = "Einen Zauber mit der ID %d gibt es in diesem Client nicht."
L["The list is full (%d debuffs)."] = "Die Liste ist voll (%d Debuffs)."
L["Your own entry. Right-click to remove it."] = "Dein eigener Eintrag. Rechtsklick entfernt ihn."
L["Reset position"] = "Position zurücksetzen"
L["Close"] = "Schließen"

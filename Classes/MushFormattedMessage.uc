class MushFormattedMessage extends CriticalEventPlus;


static function String GetNameFor(PlayerReplicationInfo PRI) {
    if (PRI.PlayerName == "") {
        if (Pawn(PRI.Owner) != None) {
            return Pawn(PRI.Owner).NameArticle $ PRI.Owner.Class.Name;
        }

        return "someone";
    }

    return PRI.PlayerName;
}

static function Format(out String FormatBase, String FormatName, String Value) {
    local int Index, ReplaceLen;

    Index = InStr(FormatBase, "{"$ FormatName $"}");

    if (Index == -1) {
        return;
    }

    ReplaceLen = 2 + Len(FormatName);

    FormatBase = Left(FormatBase, Index) $ Value $ Mid(FormatBase, Index + ReplaceLen);
}

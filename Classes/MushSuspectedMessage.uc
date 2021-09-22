class MushSuspectedMessage extends MushFormattedMessage;

var(MushMessages) localized string SuspectedString, UnsuspectedString;


static function String ParseMessage(PlayerReplicationInfo PRI_1, PlayerReplicationInfo PRI_2, bool bIsUnsuspect) {
    local String Part1, Part2, Assembled;

    Part1 = GetNameFor(PRI_1);
    Part2 = GetNameFor(PRI_2);

    if (bIsUnsuspect) {
        Assembled = default.UnsuspectedString;

        Format(Assembled, "unsuspected", Part1);
        Format(Assembled, "mush_killed", Part2);
    }

    else {
        Assembled = default.SuspectedString;
        
        Format(Assembled, "suspected", Part1);
        Format(Assembled, "suspector", Part2);
    }

    return Assembled;
}

static function string GetString(
        optional int Switch,
        optional PlayerReplicationInfo RelatedPRI_1, 
        optional PlayerReplicationInfo RelatedPRI_2,
        optional Object OptionalObject 
) {
    if (RelatedPRI_1 == None)
        return "";
    if (RelatedPRI_2 == None)
        return "";

    return ParseMessage(RelatedPRI_1, RelatedPRI_2, Switch == 1);
}



defaultproperties {
    SuspectedString="{suspector} planted a suspicion beacon on {suspected}!"
    UnsuspectedString="{unsuspected} had their suspicion voided after killing a mush, {mush_killed}!"
    bBeep=false
}
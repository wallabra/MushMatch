class MushSpottedMessage extends MushFormattedMessage;

var(MushMessages) localized string SpottedMushString;


static function String ParseMessage(PlayerReplicationInfo PRI_1, PlayerReplicationInfo PRI_2) {
    local String SubjectPart, ObjectPart, Assembled;

    Assembled = default.SpottedMushString;

    SubjectPart = GetNameFor(PRI_1);
    ObjectPart  = GetNameFor(PRI_2);

    /*
     * Note: 'subject' and 'object' are misleading - 'object' is the
     * finder or PRI_1, 'subject' is the found or PRI_2!
     *
     * In linguistics, it's be the opposite: 'subject' would be the one
     * performing an action. This ain't no linguistics.
     *
     * Will fix someday. Maybe. Perhaps never. Who knows?! I ain't got
     * a crystal ball!
     *
     *  -Gustavo
     */

    Format(Assembled, "found", SubjectPart);
    Format(Assembled, "finder", ObjectPart);

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

    return ParseMessage(RelatedPRI_1, RelatedPRI_2);
}



defaultproperties {
    SpottedMushString="{found} was discovered as a mush!"
    bBeep=true
}

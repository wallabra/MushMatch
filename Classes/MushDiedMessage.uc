class MushDiedMessage extends MushFormattedMessage;

var(MushMessages) localized string DeceasedString;
var(MushMessages) localized string MalePronoun, FemalePronoun, MushPronoun, UnknownPronoun;
var(MushMessages) localized string HumanAlignString, MushAlignString, UnknownAlignString;


static function String ParseMessage(PlayerReplicationInfo PRI, bool bMushUseOwnPronoun) {
    local String Who, Pronoun, Alignment, Assembled;

    Who = GetNameFor(PRI);

    // get pronou and alignment
    if (PRI.Team == 0) {
        Alignment = default.HumanAlignString;

        // humans have usual pronoun rules
        if (PRI.bIsFemale) {
            Pronoun = default.FemalePronoun;
        }

        else {
            Pronoun = default.MalePronoun;
        }
    }

    else {
        if (PRI.Team == 1) {
            Alignment = default.MushAlignString;

            // get mush pronoun
            if (bMushUseOwnPronoun) {
                // mush are always 'it'
                Pronoun = default.MushPronoun;
            }
    
            else {
                // use usual pronoun rules
                if (PRI.bIsFemale) {
                    Pronoun = default.FemalePronoun;
                }
        
                else {
                    Pronoun = default.MalePronoun;
                }
            }
        }

        else {
            // unknown team; 'it' was 'something'!

            Alignment = default.UnknownAlignString;
            Pronoun = default.UnknownPronoun;
        }
    }

    Assembled = default.DeceasedString;

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

    Format(Assembled, "deceased", Who);
    Format(Assembled, "pronoun", Pronoun);
    Format(Assembled, "alignment", Alignment);

    return Assembled;
}

static function string GetString(
        optional int Switch,
        optional PlayerReplicationInfo RelatedPRI_1, // the deceased
        optional PlayerReplicationInfo RelatedPRI_2, // nobody
        optional Object OptionalObject 
) {
    if (RelatedPRI_1 == None)
        return "";

    return ParseMessage(RelatedPRI_1, Switch == 1);
}



defaultproperties {
    DeceasedString="{deceased} died and is out - {pronoun} was {alignment}!"
    MalePronoun="he"
    FemalePronoun="she"
    MushPronoun="it"
    UnknownPronoun="'it'"
    HumanAlignString="human"
    MushAlignString="mush"
    UnknownAlignString="...something"
    bBeep=false
}
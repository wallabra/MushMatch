class MushSelectedMessage extends CriticalEventPlus;


var(MushMessages)   localized string    GreetStringHuman;
var(MushMessages)   localized string    GreetStringMush;


static function string GetOwnString (
    optional int Switch,
    optional PlayerReplicationInfo OwnPRI
) {
    local MushMatchPRL MPRL;

    MPRL = MushMatchInfo(PlayerPawn(OwnPRI.Owner).GameReplicationInfo).FindPRL(OwnPRI);

    if (MPRL.bMush)
        return Default.GreetStringMush;

    else
        return Default.GreetStringHuman;
}

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1, 
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	return GetOwnString(Switch, RelatedPRI_1);
}

static function ClientReceive( 
	PlayerPawn P,
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1, 
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	if ( P.myHUD != None )
		P.myHUD.LocalizedMessage( Default.Class, Switch, P.PlayerReplicationInfo, RelatedPRI_1, OptionalObject );

	if ( Default.bBeep && P.bMessageBeep )
		P.PlayBeepSound();

	if ( Default.bIsConsoleMessage )
	{
		if ((P.Player != None) && (P.Player.Console != None))
			P.Player.Console.AddString(Static.GetOwnString( Switch, P.PlayerReplicationInfo ));
	}
}

defaultproperties {
    GreetStringHuman="You are a human: Investigate, find, and mark or neutralize the mushes!"
    GreetStringMush="You are a mush: Eliminate or infect humans, but be stealthy!"

    FontSize=3
    Lifetime=8
    bIsSpecial=True
    bIsUnique=True
    bFadeMessage=True
    DrawColor=(G=0,B=0)
    YPos=240.000000
    bCenter=True
    bBeep=True
}

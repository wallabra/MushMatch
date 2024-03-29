#exec mesh import mesh=MBeaconWeap anivfile=Models\MBeaconWeap_a.3d datafile=Models\MBeaconWeap_d.3d x=0 y=0 z=0 mlod=1

#exec mesh sequence mesh=MBeaconWeap seq=All startframe=0 numframes=37 rate=19
#exec mesh sequence mesh=MBeaconWeap seq=Still startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=MBeaconWeap seq=Fire startframe=0 numframes=11 rate=18
#exec mesh sequence mesh=MBeaconWeap seq=Down startframe=11 numframes=14 rate=28
#exec mesh sequence mesh=MBeaconWeap seq=Select startframe=25 numframes=12 rate=21

#exec meshmap new meshmap=MBeaconWeap mesh=MBeaconWeap
#exec meshmap scale meshmap=MBeaconWeap x=0.1 y=0.1 z=0.2

#exec texture import name=JMBeaconWeap file=Textures\JMBeaconWeap.pcx group=Skins
#exec meshmap settexture meshmap=MBeaconWeap num=0 texture=JMBeaconWeap

class MushBeacon extends TournamentWeapon;


var(MushMatch_Game) float MinBeaconBotRating, MaxBeaconBotRating, BeaconBotRatingFalloff;
var float BeaconFirerate;


replication {
    reliable if (Role == ROLE_Authority)
        BeaconFirerate;
}

simulated function BeginPlay() {
    Super.BeginPlay();

    if (Role == ROLE_Authority) {
        UpdateConfigVars();
    }
}

// Update configuration from the MushMatch(Level.Game).
function UpdateConfigVars() {
    local MushMatch MM;
    MM = MushMatch(Level.Game);

    if (MM == None) {
        // rip
        Warn(class.name@"detected outside a Mush Match; gameinfo is"@Level.Game);
        return;
    }

    BeaconFirerate = MM.SuspicionBeaconFirerate;
}

simulated function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
{
    local Projectile pj;
    
    FireOffset.X += 15;
    
    while ( pj == None )
    {
        FireOffset.X -= 5;
    
        if ( FireOffset.X < -20 )
            return None;
        
        pj = Super.ProjectileFire(ProjClass, ProjSpeed, bWarn);
    }
    
    FireOffset.X = Default.FireOffset.X;
    
    pj.Instigator = Pawn(Owner);
    
    return pj;
}

simulated function AltFire(float Value)
{
    Fire(Value);
}

simulated event Tick(float TimeDelta)
{    
    Super.Tick(TimeDelta);
        
    if (IsInState('Pickup') && Owner == None && Inventory == None)
    {
        Destroy();
        return;
    }
}

/*
simulated function float PassiveRating()
{
    local Pawn P;
    local float Score;
    
    Score = -50;

    if ( ( Pawn(Owner).Enemy != None && Pawn(Owner).Enemy.FindInventoryType(class'SpottedMush') != None ) || Pawn(Owner) == None || MushMatch(Level.Game) == None )
        return -50000;
    
    if ( MushMatch(Level.Game).bHasHate )
        for ( P = Level.PawnList; P != None; P = P.NextPawn )
            if (
                MushMatch(Level.Game).bHasHate &&
                MushMatchInfo(Level.Game.GameReplicationInfo).CheckHate(P.PlayerReplicationInfo, Pawn(Owner).PlayerReplicationInfo) &&
                !MushMatchInfo(Level.Game.GameReplicationInfo).CheckConfirmedHuman(P.PlayerReplicationInfo) && (
                    !(MushMatch(Level.Game).bHasBeacon) || !MushMatchInfo(Level.Game.GameReplicationInfo).CheckBeacon(P.PlayerReplicationInfo)
                )
            ) //----
                Score += Max(250, 1400 - VSize(Owner.Location - P.Location)) / 4;
    
    return Score;
}
*/

function float RateSelf(out int bUseAltMode)
{
    local float Score;
    local MushMatchPRL OPRL, EPRL;
    
    if (Pawn(Owner) == None || MushMatch(Level.Game) == None)
        return -2;

    if ( (AmmoType != None) && (AmmoType.AmmoAmount <=0) )
		return -2;

    // don't bring up if a player pawn (not bot)
    if (PlayerPawn(Owner) != None)
        return -2;

    // don't bring up if not a match contestant
    if (!Pawn(Owner).bIsPlayer)
        return -2;
            
    Score = -50;
    bUseAltMode = 0;

    if (Pawn(Owner) != None && Pawn(Owner).PlayerReplicationInfo != None) {
        OPRL = MushMatchInfo(Level.Game.GameReplicationInfo).FindPRL(Pawn(Owner).PlayerReplicationInfo);
    }

    if (OPRL != None && OPRL.bKnownMush)
        return -2; // bad bad

    // rate enemy
    if (Pawn(Owner).Enemy == None) {
        return -2;
    }
    
    EPRL = MushMatchInfo(Level.Game.GameReplicationInfo).FindPRL(Pawn(Owner).Enemy.PlayerReplicationInfo);

    if (EPRL == None) {
        return -1;
    }
    
    // don't use if EPRL is a known mush
    if (EPRL.bMush) {
        return -1;
    }

    // don't use if EPRL is suspected and not wielding a Sporifier
    if (EPRL.bIsSuspected && Sporifier(Pawn(Owner).Enemy.Weapon) == None) {
        return -1;
    }
    
    Score = Max(MinBeaconBotRating,
                BeaconBotRatingFalloff * ((MaxBeaconBotRating / BeaconBotRatingFalloff) -
                                          VSize(Owner.Location - Pawn(Owner).Enemy.Location)));
    
    //Log("suspect dist"@VSize(Owner.Location - Pawn(Owner).Enemy.Location)@"=> beacon rating"@Score + 50);
    
    return Score;
}

simulated function PlayFiring()
{
    PlayAnim('Fire', BeaconFirerate, 0.1);
    PlayOwnedSound(FireSound, SLOT_Misc, 1.0);
}

simulated function PlayIdle()
{
    PlayAnim('Still', 0.35, 0.5);
}

defaultproperties
{
     AmmoName=Class'MushBeaconAmmo'
     PickupAmmoCount=5
     FireOffset=(X=32.000000)
     ProjectileClass=Class'MushBeaconProj'
     AltProjectileClass=Class'MushBeaconProj'
     FireSound=Sound'Botpack.BioRifle.GelHit'
     SelectSound=Sound'Botpack.enforcer.Cocking'
     DeathMessage="%k got crazy and killed %o with some Mush Beacon Gun..."
     PickupMessage="You got the Mush Beacon Gun."
     ItemName="Mush Beacon"
     PlayerViewOffset=(X=10.100000,Y=-6.000000,Z=-5.500000)
     PlayerViewMesh=LodMesh'MBeaconWeap'
     PlayerViewScale=0.300000
     PickupViewMesh=LodMesh'MBeaconWeap'
     ThirdPersonMesh=LodMesh'MBeaconWeap'
     ThirdPersonScale=0.600000
     StatusIcon=Texture'Botpack.Icons.UsePulse'
     MaxDesireability=0.000000
     PickupSound=Sound'Botpack.enforcer.Cocking'
     Icon=Texture'Botpack.Icons.IconPulse'
     Mesh=LodMesh'MBeaconWeap'
     Mass=65.000000
     MinBeaconBotRating=400
     MaxBeaconBotRating=2500
     BeaconBotRatingFalloff=12
     bCanThrow=false
}

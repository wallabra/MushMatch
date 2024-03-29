/*
 * Shoots "spore spits" that mushify
 * other players (and bots).
 */
 
#exec mesh import mesh=Sporifier anivfile=Models\Sporifier_a.3d datafile=Models\Sporifier_d.3d x=0 y=0 z=0 mlod=1

#exec mesh sequence mesh=Sporifier seq=All startframe=0 numframes=73 rate=35
#exec mesh sequence mesh=Sporifier seq=Still startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=Sporifier seq=Fire startframe=0 numframes=23 rate=30
#exec mesh sequence mesh=Sporifier seq=Down startframe=23 numframes=21 rate=55
#exec mesh sequence mesh=Sporifier seq=Select startframe=44 numframes=28 rate=55

#exec mesh import mesh=Sporifier3P anivfile=Models\Sporifier3P_a.3d datafile=Models\Sporifier3P_d.3d x=0 y=0 z=0 mlod=1

#exec mesh sequence mesh=Sporifier3P seq=All startframe=0 numframes=73 rate=35
#exec mesh sequence mesh=Sporifier3P seq=Still startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=Sporifier3P seq=Fire startframe=0 numframes=23 rate=30
#exec mesh sequence mesh=Sporifier3P seq=Down startframe=23 numframes=21 rate=55
#exec mesh sequence mesh=Sporifier3P seq=Select startframe=44 numframes=28 rate=55

#exec meshmap new meshmap=Sporifier mesh=Sporifier3P
#exec meshmap scale meshmap=Sporifier x=0.3 y=0.3 z=0.6
#exec meshmap rotate meshmap=Sporifier x=0 y=0 z=0

#exec meshmap new meshmap=Sporifier3P mesh=Sporifier3P
#exec meshmap scale meshmap=Sporifier3P x=1 y=1 z=2
#exec meshmap rotate meshmap=Sporifier3P x=0 y=0 z=0

#exec texture import name=JSporifier file=Textures\JSporifier.pcx group=Skins
#exec meshmap settexture meshmap=Sporifier num=0 texture=JSporifier
#exec meshmap settexture meshmap=Sporifier3P num=0 texture=JSporifier
 
class Sporifier extends TournamentWeapon;


var float SafeTime;
var bool bDesired, bAlwaysAutoSpot;
var MushMatchInfo MMI;
var MushMatchPRL PRL;

var float SporifierFirerate, SporifierAIMaxSafeTime, SporifierAIMinSafeInterval;


replication {
    reliable if (Role == ROLE_Authority)
        SporifierFirerate, SporifierAIMaxSafeTime, SporifierAIMinSafeInterval;
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

    SporifierFirerate           = MM.SporifierFirerate;
    SporifierAIMaxSafeTime      = MM.SporifierAIMaxSafeTime;
    SporifierAIMinSafeInterval  = MM.SporifierAIMinSafeInterval;
}


function PostBeginPlay()
{
    if (Role == ROLE_Authority) {
        if (MushMatch(Level.Game).bMushSelected)
            MushSelected();
    }
}

simulated function MushSelected()
{
    /*if (PlayerPawn(Owner) == None) {
        SetTimer(1.0, false);
    }*/
}

simulated function float RateSelf(out int bUseAltMode)
{
    //local Pawn P;
    local MushMatchInfo MMI;

    // No ammo.
    if ( (AmmoType != None) && (AmmoType.AmmoAmount <=0) ) {
		return -1000;
    }

    // Not owned by a bot!
    if (PlayerPawn(Owner) != None) {
        return -10000;
    }

    // On interval.
    if (SafeTime < 0) {
        return -10000;
    }

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    // Not in the match?
    if (MMI == None) {
        return -10000;
    }

    // Is desireable
    if (Role == ROLE_Authority && bDesired && PlayerPawn(Owner) == None) {
        return 50000;
    }
    
    return 0;
}

simulated function ResetSafeTime() {
    SafeTime = 0;
}

simulated function IntervalSafeTime() {
    SafeTime = -SporifierAIMinSafeInterval;
}

simulated function bool PutDown() {
    bDesired = false;

    return Super.PutDown();
}

simulated function PlayFiring()
{
    PlayAnim('Fire', SporifierFirerate, 0.05);
    PlayOwnedSound(FireSound, SLOT_Misc, 1.0);
}

simulated function PlayIdle()
{
    PlayAnim('Still', 0.35, 0.5);
}

simulated function FindOwnPRL() {
    FindMMI();

    if (PRL != None && PRL.Owner == Pawn(Owner).PlayerReplicationInfo) {
        return;
    }

    PRL = MMI.FindPRL(Pawn(Owner).PlayerReplicationInfo);

    return;
}

simulated function FindMMI() {
    if (MMI != None) {
        return;
    }

    if (Role == ROLE_Authority) {
        MMI = MushMatchInfo(Level.Game.GameReplicationInfo);
    }

    else {
        MMI = MushMatchInfo(PlayerPawn(Owner).GameReplicationInfo);
    }
}

simulated function Tick(float TimeDelta)
{   
    Super.Tick(TimeDelta);

    if (IsInState('Pickup') && Owner == None && Inventory == None)
    {
        Destroy();
        return;
    }

    if (PlayerPawn(Owner) != None && (AmmoType != None) && (AmmoType.AmmoAmount <= 0)) {
        PutDown();
        return;
    }
    
    if (Pawn(Owner).Weapon != Self) {
        if (PlayerPawn(Owner) == None && SafeTime < 0.0) {
            bDesired = false;
            SafeTime += TimeDelta;

            if (SafeTime > 0.0) {
                SafeTime = 0.0;
            }
        }

        return;
    }

    FindOwnPRL();
    
    if (PRL == None) {
        return;
    }

    if (PRL.bKnownMush) {
        return;
    }

    if (Role == ROLE_Authority) {
        if (PRL != None && (!PRL.bMush)) {
            if (!PRL.bMush) {
                Warn("Sporifier"@ self @"had a non-Mush owner,"@ Owner);
            }

            Pawn(Owner).DeleteInventory(Self);
            Destroy();
            return;
        }

        if (PRL.bDead) {
            return;
        }
    
        if (!IsInState('BringUp') && AnimSequence != 'Select' && AnimSequence != 'Down') {
            CheckSpotted();
        }

        if (PlayerPawn(Owner) == None) {
            SafeTime += TimeDelta;
            
            if (SafeTime >= SporifierAIMaxSafeTime) {
                if (Role == ROLE_Authority) {
                    bDesired = false; // just in case we don't get put down
                    PutDown();
                    Pawn(Owner).SwitchToBestWeapon();
                }
            }
        }
    }
}

function CheckSpotted() {
    local MushMatchPRL PPRL;
    local Pawn p;
    local bool bAutoSpot;

    bAutoSpot = !MushMatch(Level.Game).bBeaconCanSpotMush || bAlwaysAutoSpot;
    
    for (p = Level.PawnList; p != none; p = p.nextPawn) {
        if (!p.bIsPlayer) continue;
        if (p == Owner) continue;
        if (p.PlayerReplicationInfo == none) continue;

        PPRL = MMI.FindPRL(P.PlayerReplicationInfo);

        if (PPRL == None) continue;
        if (p.Health <= 0 || PPRL.bDead) continue;
        if (PPRL.bMush) continue;

        if (!p.CanSee(Owner)) continue;

        if (bAutoSpot) {
            MushMatch(Level.Game).SpotMush(Pawn(Owner), p);
            break;
        }

        else {
            MushMatch(Level.Game).RegisterHate(p, Pawn(Owner));
        }
    }
}

function AltFire(float Value)
{
	return; // alt fire do nothing
}

function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
{
    local Projectile pj;
    
    // Sporifier in active use, don't randomly put down!
    if (PlayerPawn(Owner) == None) {
        ResetSafeTime();
    }

    pj = Super.ProjectileFire(ProjClass,  ProjSpeed, bWarn);

    if (pj == None) {
        return None;
    }

    pj.Instigator = Pawn(Owner);

    return pj;
}

defaultproperties
{
     AmmoName=Class'SporeCanister'
     PickupAmmoCount=20
     FireOffset=(X=32.000000)
     ProjectileClass=Class'SporeProj'
     AltProjectileClass=Class'SporeProj'
     FireSound=Sound'Botpack.BioRifle.GelHit'
     SelectSound=Sound'Botpack.enforcer.Cocking'
     DeathMessage="%o somehow died. And %k promised the mush would fix their defects. Huh."
     InventoryGroup=10
     PickupMessage="You got the Sporifier."
     ItemName="Sporifier"
     PlayerViewOffset=(X=43.000000,Y=-28.000000,Z=-20.500000)
     PlayerViewMesh=LodMesh'Sporifier'
     PickupViewMesh=LodMesh'Sporifier'
     ThirdPersonMesh=LodMesh'Sporifier3P'
     ThirdPersonScale=0.9
     StatusIcon=Texture'Botpack.Icons.UsePulse'
     MaxDesireability=0.000000
     PickupSound=Sound'Botpack.enforcer.Cocking'
     Icon=Texture'Botpack.Icons.IconPulse'
     Mesh=LodMesh'Sporifier'
     Mass=35.000000
     bAltWarnTarget=false
     bWarnTarget=false
     SporifierFirerate=1.5
     bAlwaysAutoSpot=false
     bCanThrow=false
}

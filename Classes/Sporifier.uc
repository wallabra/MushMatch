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


var bool bDanger;

var config(MushMatch) float SporifierFirerate;


replication {
    reliable if (Role == ROLE_Authority)
        bDanger;
}


function PostBeginPlay()
{
    if (Role == ROLE_Authority) {
        if (PlayerPawn(Owner) == None) {
            bDanger = true;
        }
        
        if (MushMatch(Level.Game).bMushSelected)
            MushSelected();
    }
}

simulated function MushSelected()
{
    if (PlayerPawn(Owner) == None) {
        SetTimer(1.0, false);
    }
}

simulated function float RateSelf(out int bUseAltMode)
{
    local Pawn P;
    local MushMatchInfo MMI;

    if ( (AmmoType != None) && (AmmoType.AmmoAmount <=0) )
		return -2;

    if (PlayerPawn(Owner) != None) return -10000;

    MMI = MushMatchInfo(Level.Game.GameReplicationInfo);

    if (MMI == None) return -2;
    
    bUseAltMode = 0;

    if (PlayerPawn(Owner) == None && !MMI.CheckConfirmedMush(Pawn(Owner).PlayerReplicationInfo)) {
        for ( P = Level.PawnList; P != none; P = P.nextPawn )
            if (P.bIsPlayer && ( ( FastTrace(P.Location) && P.CanSee(Owner) && P.PlayerReplicationInfo.Team == 0 && FRand() > 0.625 ) || P.Enemy == Owner || Pawn(Owner).PlayerReplicationInfo.Team == 0 ) ) {
                bDanger = true;
                SetTimer(2.0, false);
                
                return 0;
            }
            
            else if ( bDanger )
                return 0;
    }   
            
    return 9000000;
}

simulated function Timer()
{
    if ( bDanger )
        bDanger = false;
        
    else
        Super.Timer();
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

simulated function Tick(float TimeDelta)
{
    local Pawn p;
    
    Super.Tick(TimeDelta);
        
    if ( Owner == None || Owner.IsInState('Dying') || ( MushMatch(Level.Game) == none && Pawn(Owner).PlayerReplicationInfo != none && Pawn(Owner).PlayerReplicationInfo.Deaths > 0 ) )
    {
        Destroy();
        return;
    }
    
    if ( Pawn(Owner).Weapon != self ) return;
    
    for ( p = Level.PawnList; p != none; p = p.nextPawn )
        if ( p.bIsPlayer && p != Owner && p.PlayerReplicationInfo != none && p.PlayerReplicationInfo.Deaths <= 0 && p.CanSee(Owner) && Pawn(Owner).PlayerReplicationInfo.Team == 1  && p.PlayerReplicationInfo.Team == 0 )
            MushMatch(Level.Game).SpotMush(Pawn(Owner), p);
}

function AltFire(float Value)
{
	return; // alt fire do nothing
}


function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
{
    local Projectile pj;
    
    FireOffset.X += 15;
    
    while (pj == None) {
        FireOffset.X -= 15;
    
        if (FireOffset.X < -32) {
            if (Role == ROLE_Authority && Pawn(Owner) != None)
                Warn(Pawn(Owner).PlayerReplicationInfo.PlayerName @"could not fire projectile from Sporifier!");
        
            return None;
        }
        
        pj = Super.ProjectileFire(ProjClass, ProjSpeed, bWarn);
    }
    
    FireOffset.X = Default.FireOffset.X;
    
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
     DeathMessage="%o somehow died. And %k promised the mush would fix his defects. Huh."
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
}

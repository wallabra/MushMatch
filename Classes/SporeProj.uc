#exec mesh import mesh=SporeProj anivfile=Models\SporeProj_a.3d datafile=Models\SporeProj_d.3d x=0 y=0 z=0 mlod=1
#exec mesh scale mesh=SporeProj x=1 y=1 z=1

#exec mesh sequence mesh=SporeProj seq=All startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=SporeProj seq=Still startframe=0 numframes=1 rate=1
#exec mesh sequence mesh=SporeProj seq=Flying startframe=0 numframes=6 rate=6

#exec meshmap new meshmap=SporeProj mesh=SporeProj
#exec meshmap scale meshmap=SporeProj x=0.1 y=0.1 z=0.2

#exec texture import name=JSporeProj file=Textures\JSporeProj.pcx group=Skins
#exec meshmap settexture meshmap=SporeProj num=0 texture=JSporeProj

#exec texture import name=SporeDecal file=Textures\SporeDecal.pcx group=Decals

#exec AUDIO IMPORT FILE="Sounds\mm_infect.wav" NAME="Infected" GROUP="MushMatch"

class SporeProj extends Projectile;

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();

    Velocity = Vector(Rotation) * speed;
    SetPhysics(PHYS_Projectile);
    SetRotation(Rotator(Velocity));

    if (Level.NetMode != NM_Standalone) {
        LoopAnim('Flying', 6, 0.1);
    }
}

simulated function Tick(float TimeDelta)
{
    local Rotator r;
    r = Rotation;

    Super.Tick(TimeDelta);

    if ( Role != ROLE_Authority )
        SetRotation(Rotator(Velocity));
        
    r.Roll += TimeDelta * 65536;
    SetRotation(r);
}

function ProcessTouch(Actor Other, Vector HitLocation)
{
    local Pawn mushed;
    local Weapon w;
    
    Super.ProcessTouch(Other, HitLocation);

    if ( Instigator == None ) {
        Warn("Null instigator found!");
        Destroy();

        return;
    }
    
    if ( Other == Instigator ) {
        return;
    }
    
    if ( Pawn(Other) != none && Instigator != none && Pawn(Other).bIsPlayer && Pawn(Other).PlayerReplicationInfo != none && Pawn(Other).PlayerReplicationInfo.Team == 0 && Instigator.PlayerReplicationInfo != None && Instigator.PlayerReplicationInfo.Team == 1 ) {
        if (Role == ROLE_Authority) {
            mushed = Pawn(Other);
            
            Spawn(class'Sporifier').GiveTo(mushed); // HA! You are now a mush!
            
            mushed.Weapon = w;
            mushed.PlayerReplicationInfo.Team = 1; // 0 = human, 1 = mush
            
            Instigator.PlayerReplicationInfo.Score += 1;
                
            mushmatch(Level.Game).CheckEnd();
            
            if ( mushed.Enemy == Instigator ) mushed.Enemy = none;
            if ( mushed == Instigator.Enemy ) instigator.Enemy = none;
            
            // -- Infections are low-key, don't alert everyone in a newly infected mush's vicinity, that's dumb. -- {
            //     for ( p = Level.PawnList; p != none; p = p.nextPawn )
            //         if ( p.bIsPlayer && p != mushed && p.PlayerReplicationInfo != none && p.PlayerReplicationInfo.Deaths <= 0 && p.CanSee(mushed) && mushed.PlayerReplicationInfo.Team == 1  && p.PlayerReplicationInfo.Team == 0 )
            //             mushmatch(Level.Game).SpotMush(mushed, p);
            // }
                    
            if ( PlayerPawn(mushed) != None && !MushMatch(Level.Game).bMatchEnd )
                mushed.PlayOwnedSound(sound'Infected');
        }
    }

    Destroy();
}

defaultproperties
{
     speed=1000.000000
     MaxSpeed=1100.000000
     MomentumTransfer=4
     ImpactSound=Sound'Botpack.Pickups.AmmoPick'
     RemoteRole=ROLE_SimulatedProxy
     Mesh=LodMesh'SporeProj'
     CollisionRadius=10.000000
     CollisionHeight=10.000000
}

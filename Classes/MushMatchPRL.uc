class MushMatchPRL extends PlayerReplicationList;

var             bool                    bIsSuspected;
var             bool                    bMush;
var             bool                    bKnownMush, bKnownHuman;
var             bool                    bDead;
var             byte                    InitialTeam;
var             float                   ImmuneLevel;
var             float                   ImmuneMomentum, ImmuneResistance;
var             PlayerReplicationList   HatedBy;
var(MushMatch)  config float            ImmuneMomentumDrag,
                                            ImmuneMomentumThreshold,
                                            ImmuneNaturalRegen,
                                            ImmuneNaturalFallback,
                                            ImmuneNaturalSnapThreshold,
                                            ImmuneHitAmount,
                                            InstantImmuneHitFactor,
                                            ImmuneDangerLevel;

var(MushMatch)  config bool             bImmuneNaturallyTendsToFull,
                                            bImmuneSnap,
                                            bNoNegativeImmune,
                                            bNoSuperImmune,
                                            bImmuneInstantHit;


replication
{
    reliable if (Role == ROLE_Authority)
        bIsSuspected, bMush, bKnownHuman, bKnownMush, bDead, InitialTeam, HatedBy,

        // immune level and its parameters
        ImmuneLevel, ImmuneResistance, ImmuneMomentum, ImmuneMomentumThreshold, ImmuneMomentumDrag,
        ImmuneNaturalRegen, ImmuneNaturalFallback, ImmuneNaturalSnapThreshold, ImmuneHitAmount,
        InstantImmuneHitFactor, ImmuneDangerLevel,

        // immune level configurations
        bImmuneNaturallyTendsToFull, bImmuneSnap,
        bNoNegativeImmune, bNoSuperImmune,
        bImmuneInstantHit,

        SetInitialTeam;
}


simulated event Tick(float TimeDelta) {
    if (Abs(ImmuneMomentum) >= ImmuneMomentumThreshold) {
        ImmuneLevel += ImmuneMomentum * TimeDelta;

        if (ImmuneLevel < 0.0 && bNoNegativeImmune) {
            ImmuneLevel = 0.0;
        }

        if (ImmuneLevel > 1.0 && bNoSuperImmune) {
            ImmuneLevel = 1.0;
        }

        ImmuneMomentum -= ImmuneMomentum * TimeDelta * ImmuneMomentumDrag;

        if (Abs(ImmuneMomentum) < ImmuneMomentumThreshold) {
            ImmuneMomentum = 0.0;
        }
    }

    if (bImmuneNaturallyTendsToFull) {
        if (Abs(ImmuneLevel - 1.0) < ImmuneNaturalSnapThreshold) {
            if (ImmuneMomentum == 0.0 && bImmuneSnap) {
                ImmuneLevel = 1.0;
            }
        }

        else if (ImmuneLevel < 1.0) {
            ImmuneLevel += ImmuneNaturalRegen * TimeDelta;
        }

        else if (!bNoSuperImmune) {
            ImmuneLevel -= ImmuneNaturalFallback * TimeDelta;
        }
    }
}

function PostBeginPlay() {
    // Assert Owner is a PlayerReplicationInfo.
    if (PlayerReplicationInfo(Owner) == None) {
        Log(self@"is not owned by a PlayerReplicationInfo! Owner:"@Owner);
        return;
    }

    InitialTeam = PlayerReplicationInfo(Owner).Team;
}

simulated function ImmuneHit(float Amount) {
    ImmuneMomentum -= Amount / ImmuneResistance;

    // Also decrease immune-resistance a little
    if (ImmuneResistance > 1.0) {
        ImmuneResistance /= Sqrt(Amount / (ImmuneResistance + 1.0));
    }
}

function TryToMush(Pawn Instigator) {
    local Pawn mushed;

    if (Role != ROLE_Authority) {
        return;
    }

    // Get Pawn owner, and do sanity checks

    mushed = Pawn(Owner.Owner);

    if (mushed == None) {
        Warn("Could not find Pawn who is the Owner of the PlayerReplicationInfo that should in turn be" @self@ "'s owner!");
        return;
    }

    // Check if immune level low enough for mushing

    if (bImmuneInstantHit) {
        ImmuneLevel -= ImmuneHitAmount * InstantImmuneHitFactor;
    }

    if (ImmuneLevel <= ImmuneDangerLevel) {
        MushMatch(Level.Game).MakeMush(mushed, Instigator);
        return;
    }

    // If not, just take it as an immune hit

    if (!bImmuneInstantHit) {
        ImmuneHit(1.0);
        return;
    }
}

simulated event bool HasHate(PlayerReplicationInfo Other)
{
    if (HatedBy == None)
        return false;

    return HatedBy.FindPlayer(Other) != None;
}

simulated event bool HasHateOnPlayer(PlayerReplicationInfo Other)
{
    local MushMatchPRL OtherMPRL;

    OtherMPRL = MushMatchPRL(Root.FindPlayer(Other));

    return HasHateOnPRL(OtherMPRL);
}

simulated event bool HasHateOnPRL(MushMatchPRL Other)
{
    if (Other == None || Other.HatedBy == None)
        return false;

    return Other.HatedBy.FindPlayer(PlayerReplicationInfo(Owner)) != None;
}


simulated event bool HasAnyHate()
{
    return HatedBy != None;
}

simulated event AddHate(PlayerReplicationInfo Other)
{
    if ( HatedBy == None ) {
        HatedBy = Other.Spawn(class'PlayerReplicationList', Other);
    }

    else {
        HatedBy.AppendPlayer(Other);
    }
}

simulated event bool RemoveHate(PlayerReplicationInfo Other)
{
    if ( HatedBy == None )
        return false;

    else {
        return HatedBy.RemovePlayer(Other, HatedBy);
    }
}

simulated event SetInitialTeam() {
    InitialTeam = PlayerReplicationInfo(Owner).Team;
}


defaultproperties
{
    bIsSuspected=false
    bKnownMush=false
    bKnownHuman=false
    bDead=false
    HatedBy=none
    ImmuneLevel=1.0
    ImmuneMomentum=0.0
    ImmuneMomentumThreshold=0.05
    ImmuneMomentumDrag=0.5
    ImmuneResistance=1.1
    ImmuneNaturalRegen=0.1
    ImmuneNaturalFallback=0.04
    ImmuneNaturalSnapThreshold=0.025
    bImmuneNaturallyTendsToFull=True
    bImmuneSnap=True
    bNoNegativeImmune=True
    bNoSuperImmune=False
    bImmuneInstantHit=False
    InstantImmuneHitFactor=1.15
    ImmuneHitAmount=0.75
    ImmuneDangerLevel=0.2
    InitialTeam=0
}

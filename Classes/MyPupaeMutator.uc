/**
 * @brief This is my example mutator. Weeeee!
 *
 * My own, very new, mutator spawns Pupae whenever a
 * player takes damage. Cool-tastic!
 *
 * @author John Doofus
 * @date 2021
 * @version 1.0
 * @bug Not enough Pupae!!!!1one
 * @copyright ISC License.
 */
class MyPupaeMutator expands Mutator;

var()   config int
    DamagePerPupae,
    MaxTriesPerPupae;

var()   config float
    SpawnOffsetMin,
    SpawnOffsetMax;



function PreBeginPlay()
{
    Super.PreBeginPlay();
    Level.Game.RegisterDamageMutator(Self);
}


/**
 * @brief Entry point for a mutator to handle damage. This is where we check to spawn Pupae!
 *
 * Checks to spawn Pupae, usually one per 'DamagePerPupae' units of
 * damage.
 *
 * @param[in,out]   ActualDamage    The damage taken. Can be modified by MutatorTakeDamage.
 * @param[in]       Victim          The Pawn taking the damage.
 * @param[in]       InstigatedBy    The Pawn dealing damage, if one was responsible. Otherwise, None.
 * @param[in,out]   HitLocation     The location of the hit relative to the Pawn taking damage. Can be modified.
 * @param[in,out]   Momentum        The momentum imparted onto the pawn by the damage. Can be modified.
 * @param[in]       DamageType      The damage type string of this damage. Deprecated?
 */
function MutatorTakeDamage(out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType) {
    local int NumPupae, i;
    local Pupae NewPupae;

    // Call the next mutator's MutatorTakeDamage first.
    if (NextMutator != None) {
        NextMutator.MutatorTakeDamage(ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType);
    }

    // Don't spawn pupae if there is no one to blame.
    if (InstigatedBy == None) {
        return;
    }

    // Ensure CanBePupaed gives the green light.
    if (!CanBePupaed(Victim, InstigatedBy)) {
        return;
    }

    // Find out how many pupae we want to spawn!
    NumPupae = (ActualDamage - ActualDamage % DamagePerPupae) / DamagePerPupae;

    // Chance to add more pupae for any remainder of damage that is not a multiple of DamgePerPupae
    if (ActualDamage % DamagePerPupae >= FRand() * DamagePerPupae) {
        NumPupae++;
    }

    Log(Self @"saw"@ ActualDamage @"damage on"@ Victim $", wants to add"@ NumPupae @"pupae");

    // Spawn each one of the desired amount! Or as many as we can.
    // Whichever limit we hit first.
    for (i = 1; i <= NumPupae; i++) {
        NewPupae = SpawnPupaeAround(Victim);

        // If one fails, just give up right away. ;-;
        if (NewPupae == None) {
            break;
        }

        // Boom! Pupae!!!! :D
        Log(Victim@ "Pupae'd by" @InstigatedBy$ "; say hi to Pupae #"$ i $","@ NewPupae);
    }
}

/**
 * @brief Tells whether someone is ripe for Pupaeing.
 *
 * This will return True only for targets where it is okay to
 * spawn Pupae around. Primarily, we don't really care to
 * spawn Pupae around other monsters, or Pupae themselves.
 *
 * @param[in]   Target      Pawn for whom to check whether it is okay to spawn Pupae(s) around.
 * @param[in]   Instigator  Pawn who dealed the damage that triggered this in the first place. You monster!
 * @returns                 Whether it is okay... to spawn Pupae(s) around Target... er, this is self-explanatory, geesh.
 */
function bool CanBePupaed(Pawn Target, Pawn Instigator) {
    local Pawn.EAttitude Attitude;

    Attitude = Target.AttitudeToPlayer;

    // Do not spawn Pupae from being damaged by a Pupae!
    if (Pupae(Instigator) != None) {
        return false;
    }

    // Only spawn Pupae around players, or active members of the match,
    // or (for a bit of fun) if damaging innocent little monsters.
    if (!Target.bIsPlayer) {
        // Check for innocence.
        if (
            !(
                Attitude == ATTITUDE_Friendly ||
                Attitude == ATTITUDE_Follow   ||
                Attitude == ATTITUDE_Ignore
            ) && Target.Enemy != Instigator
        ) {
            // Guilty!
            return false;
        }
    }

    // Don't spawn Pupae around other Pupae, even ones that are players.
    if (Pupae(Target) != None) {
        return false;
    }

    // Don't spawn Pupae if the target is dead, even if the damage event
    // is also the reason they're dead.
    if (Target.Health <= 0) {
        return false;
    }

    // Don't spawn Pupae on team damage.
    if (Level.Game.bTeamGame && (
        Target.PlayerReplicationInfo        != None &&
        Instigator.PlayerReplicationInfo    != None &&
        Target.PlayerReplicationInfo.Team   == Instigator.PlayerReplicationInfo.Team
    )) {
        return false;
    }

    // PUPAAAAAAAAAAE!
    return true;
}

/**
 * @brief Adjusts an offset vector by an actor's collision cylinder.
 *
 * @param[in,out]   Direction   The vector to be adjusted.
 * @param[in]       Collider    The actor whose cylinder to adjust against.
 */
function AdjustCollisionOffset(out Vector Direction, Actor Collider) {
    local float Verti;
    Verti = Abs(Normal(Direction).Z);

    Direction *= (Collider.CollisionRadius * (1.0 - Verti)) + (Collider.CollisionHeight * Verti);
}

/**
 * @brief Tries to pawns a Pupae around someone!
 *
 * Tries to spawn a Pupae around someone. If it doesn't
 * work, returns false. :<
 *
 * But if it does work, returns true! :D
 *
 * @param[in]   Target  Person around whom to spawn Pupae!
 * @returns             A Pupae if spawning worked, or None otherwise. I hope it did!
 */
function Pupae SpawnPupaeAround(Actor Target) {
    local int Tries;
    local Pupae Result;

    Tries = MaxTriesPerPupae;

    // Check in NumTries directions around the target.
    while (Tries-- > 0) {
        Result = TrySpawnPupaeAround(Target);

        if (Result != None) {
            return Result;
        }
    }

    // ;-;
    return None;
}

/**
 * @brief Tries once to spawn a single Pupae around Target.
 * 
 * @param   Target  The actor around which to try to spawn a Pupae.
 * @returns         A Pupae if this attempt worked, or None otherwise.
 */
function Pupae TrySpawnPupaeAround(Actor Target) {
    local Vector Offset;
    local float OffsetAmount;
    local Pupae ThePupae;

    // Get an offset for attempting to spawn one.
    OffsetAmount = 1.5;

    Offset = VRand();
    Offset *= FRand() * (SpawnOffsetMax - SpawnOffsetMin) + SpawnOffsetMin;

    AdjustCollisionOffset(Offset, Target);

    // Try to spawn!
    ThePupae = Target.Spawn(class'UnrealI.Pupae',,, Target.Location + Offset);

    if (ThePupae != None) {
        return ThePupae;
    }

    return None;
}


defaultproperties {
    DamagePerPupae=5
    MaxTriesPerPupae=10
    SpawnOffsetMin=1.2
    SpawnOffsetMax=2.0
}

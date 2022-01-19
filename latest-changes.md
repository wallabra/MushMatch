## Changelog

Implemented changes in Mush Match **v1.3.2** listed below.

 * Never allow any damage through if mush are not selected yet
 * Prevent scoring for killing monsters and other non-players
 * Allow building on Linux without requiring the manual installation of Go and Mustache
 * Finally remove vestigial class ArenaMush, the arena compatibility mutator
 * Change the default behaviour for a human's a negative contribution score (e.g. for teamkilling) to become zero, rather than positive, after infection
 * Clean up and fix suspicion related code
 * Tweak suspicion related chances and the specific circumstances which impact them

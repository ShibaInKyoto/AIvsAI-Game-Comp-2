class_name DiveScore
extends RefCounted
## Scores a finished dive so runs can be compared across frames, outcomes and
## pressure levels. Depth descended counts the most; what was hunted, learned and
## salvaged on the way adds to it, and pressure multiplies the sum.

const PER_KILL := 25
const PER_AMBUSH := 15
const PER_SCAN := 60
const PER_LOG := 150
const SURFACED_BONUS := 400
const VICTORY_BONUS := 4000
## Extra multiplier per pressure level.
const PRESSURE_STEP := 0.25


## The score's parts as [label, points] pairs, before the pressure multiplier.
static func breakdown(run: RunState) -> Array:
	var parts: Array = [
		["depth", run.descent()],
		["creatures", run.kills * PER_KILL],
		["ambushes", run.ambushes * PER_AMBUSH],
		["scans", run.scans * PER_SCAN],
		["logs", run.logs * PER_LOG],
		["salvage", run.salvage],
	]
	match run.outcome:
		RunState.Outcome.SURFACED:
			parts.append(["surfaced", SURFACED_BONUS])
		RunState.Outcome.VICTORY:
			parts.append(["Choir silenced", VICTORY_BONUS])
	return parts.filter(func(p: Array) -> bool: return int(p[1]) > 0)


static func multiplier(run: RunState) -> float:
	return (1.0 + PRESSURE_STEP * run.pressure) * Contracts.score_mult(run.contract)


static func total(run: RunState) -> int:
	var sum := 0
	for p: Array in breakdown(run):
		sum += int(p[1])
	return roundi(sum * multiplier(run))


## One line explaining the total, e.g. "depth 1,840 + creatures 125 + ...".
static func describe(run: RunState) -> String:
	var bits := PackedStringArray()
	for p: Array in breakdown(run):
		bits.append("%s %s" % [p[0], UiUtil.thousands(int(p[1]))])
	var text := " + ".join(bits)
	var why := PackedStringArray()
	if run.pressure > 0:
		why.append("pressure %d" % run.pressure)
	var terms := Contracts.find(run.contract)
	if terms:
		why.append(terms.name)
	if not why.is_empty():
		text += ",  x%.2f %s" % [multiplier(run), " + ".join(why)]
	return text


## How a dive ended, for the records table.
static func outcome_label(run: RunState) -> String:
	match run.outcome:
		RunState.Outcome.VICTORY:
			return "Choir silenced"
		RunState.Outcome.SURFACED:
			return "Surfaced"
	return "Imploded" if run.hull <= 0.0 else "Abandoned"


## The entry filed in [member MetaState.records] for a finished dive.
static func record(run: RunState, date: String) -> Dictionary:
	return {
		"score": total(run), "frame": String(run.frame_id), "depth": run.deepest_depth, "zone": run.zone,
		"outcome": outcome_label(run), "pressure": run.pressure, "daily": run.daily, "date": date,
		"contract": String(run.contract),
	}

// Crossbowman brain

#define SERVER_ONLY

#include "BrainCommon.as"
#include "FirelancerCommon.as"

void onInit(CBrain@ this)
{
	InitBrain(this);
}

void onTick(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotlances = hasLances(blob);
		if (!gotlances)
		{
			strategy = Strategy::idle;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget)
		{
			strategy = Strategy::attacking;
		}

		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}

		blob.set_u8("strategy", strategy);
	}
	else
	{
		RandomTurn(blob);
	}

	FloatInWater(blob);
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	if (strategy == Strategy::chasing)
	{
		AttackBlob(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		AttackBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		AttackBlob(blob, target);
	}
}


void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = blob.get_s32("difficulty");

	JumpOverObstacles(blob);

	const u32 gametime = getGameTime();

	// fire

	if (targetDistance > 25.0f)
	{
		blob.setAimPos(targetPos);
		blob.setKeyPressed(key_action1, true);
	}
	else
	{
		blob.setAimPos(targetPos);
		blob.setKeyPressed(key_action2, true);
	}
}


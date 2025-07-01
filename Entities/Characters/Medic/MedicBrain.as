// Knight brain

#define SERVER_ONLY

#include "BrainCommon.as"


void onInit(CBrain@ this)
{
	InitBrain(this);
	CBlob @blob = this.getBlob();
	if (blob !is null)
		blob.set("target_ally", null);
}

void onTick(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();
	//if (sv_test)
	//	return;
	//	 blob.setKeyPressed( key_action2, true );
	//	return;
	// logic for target

	this.getCurrentScript().tickFrequency = 1;//29;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget)
		{
			const s32 difficulty = blob.get_s32("difficulty");
			if (!blob.isKeyPressed(key_action1) && getGameTime() % 300 < 240 && distance < 30.0f + 3.0f * difficulty)
				strategy = Strategy::retreating;
		}
		else
		{
			strategy = Strategy::idle;
		}

		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}

		blob.set_u8("strategy", strategy);
	}

	{
		u8 strategy = blob.get_u8("strategy");
		if (strategy != Strategy::retreating)
		{
			// find injured ally
			CBlob @ally;
			blob.get("target_ally", @ally);

			if (ally is null)
			{
				blob.set("target_ally", null);
			}
			else if (LoseTarget(this, ally))
			{
				blob.set("target_ally", null);
				@ally = null;
			}
			else if (ally.getHealth >= ally.getInitialHealth())
			{
				blob.set("target_ally", null);
				@ally = null;
			}

			if (ally is null)
			{
				CBlob@[] players;
				getBlobsByTag("player", @players);
				Vec2f pos = blob.getPosition();
				for (uint i = 0; i < players.length; i++)
				{
					CBlob@ potential = players[i];
					Vec2f pos2 = potential.getPosition();
					const bool isBot = blob.getPlayer() !is null && blob.getPlayer().isBot();
					if (potential !is blob && blob.getTeamNum() == potential.getTeamNum()
							&& potential.getHealth() < potential.getInitialHealth()
					        && (pos2 - pos).getLength() < 600.0f
					        && (isBot || isVisible(blob, potential))
					        && !potential.hasTag("dead") && !potential.hasTag("migrant")
					   )
					{
						blob.set_Vec2f("last pathing pos", potential.getPosition());
						blob.set("target_ally", @potential);
						@ally = @potential;
					}
				}
			}

			if (ally !is null)
			{
				f32 distance;
				const bool visibleTarget = isVisible(blob, ally, distance);
				if (visibleTarget && distance < 50.0f)
				{
					strategy = Strategy::attacking;
				}

				if (strategy == Strategy::idle)
				{
					strategy = Strategy::chasing;
				}
				else if (strategy == Strategy::chasing)
				{
				}
				else if (strategy == Strategy::attacking)
				{
					if (!visibleTarget || distance > 120.0f)
					{
						strategy = Strategy::chasing;
					}
				}

				UpdateBlob(blob, ally, strategy);
			}
			else
			{
				strategy = Strategy::idle;
			}

			blob.set_u8("strategy", strategy);
		}
	}

	FloatInWater(blob);
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	if (strategy == Strategy::chasing)
	{
		DefaultChaseBlob_Medic(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		DefaultRetreatBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		AttackBlob(blob, target);
	}
}

void DefaultChaseBlob_Medic(CBlob@ blob, CBlob @target)
{
	CBrain@ brain = blob.getBrain();
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	Vec2f targetVector = targetPos - myPos;
	f32 targetDistance = targetVector.Length();
	// check if we have a clear area to the target
	bool justGo = false;

	if (targetDistance < 120.0f)
	{
		Vec2f col;
		if (isVisible(blob, target))
		{
			justGo = true;
		}
	}

	// repath if no clear path after going at it
	if (XORRandom(50) == 0 && (blob.get_Vec2f("last pathing pos") - targetPos).getLength() > 50.0f)
	{
		brain.SetPathTo(target.getPosition(), false);
		blob.set_Vec2f("last pathing pos", targetPos);
	}

	const bool stuck = brain.getState() == CBrain::stuck;

	const CBrain::BrainState state = brain.getState();
	{
		if (!isFriendAheadOfMe(blob, target))
		{
			if (state == CBrain::has_path)
			{
				brain.SetSuggestedKeys();  // set walk keys here
			}
			else
			{
				JustGo(blob, target);
			}
		}

		// printInt("state", this.getState() );
		switch (state)
		{
			case CBrain::idle:
				brain.SetPathTo(target.getPosition(), false);
				break;

			case CBrain::searching:
				//if (sv_test)
				//	set_emote( blob, "dots" );
				break;

			case CBrain::stuck:
				brain.SetPathTo(target.getPosition(), false);
				break;

			case CBrain::wrong_path:
				brain.SetPathTo(target.getPosition(), false);
				break;
		}
		}

	// face the enemy
	blob.setAimPos(target.getPosition());

	// jump over small blocks
	JumpOverObstacles(blob);
}

void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = blob.get_s32("difficulty");

	if (targetDistance > blob.getRadius() + 15.0f)
	{
		Chase(blob, target);
	}

	JumpOverObstacles(blob);

	// aim always at enemy
	blob.setAimPos(targetPos);

	const u32 gametime = getGameTime();

	if (targetDistance < 20.0f)
	{
		blob.setKeyPressed(key_action1, true);
	}
}


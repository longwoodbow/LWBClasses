// brain
// added moba scripts

#include "/Entities/Common/Emotes/EmotesCommon.as"
#include "BrainCommon.as"
// added getthis tag for target
CBlob@ getBuildTarget(CBrain@ this, CBlob @blob, const bool seeThroughWalls = false, const bool seeBehindBack = false)
{
	CBlob@[] players;
	Vec2f pos = blob.getPosition();
	CMap@ map = blob.getMap();
	map.getBlobsInRadius(pos, 50.0f, @players);
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		
		if (potential !is blob && blob.getTeamNum() != potential.getTeamNum()
		        && (pos2 - pos).getLength() < 120.0f
		        && (seeBehindBack || Maths::Abs(pos.x - pos2.x) < 40.0f || (blob.isFacingLeft() && pos.x > pos2.x) || (!blob.isFacingLeft() && pos.x < pos2.x))
		        && (seeThroughWalls || isVisible(blob, potential))
		        && !potential.hasTag("dead") && !potential.hasTag("migrant")
				&&  (potential.hasTag("getthis") || potential.hasTag("player"))
		   )
		{
			blob.set_Vec2f("last pathing pos", potential.getPosition());
			return potential;
		}
	}
	return null;
}

void goLeft(CBlob@ this)
{
	if(!nextToHall(this))
	{
		this.setKeyPressed(key_left, true);
		JumpOverObstacles(this);
	}
}
void goRight(CBlob@ this)
{
	if(!nextToHall(this))
	{
		this.setKeyPressed(key_right, true);
		JumpOverObstacles(this);
	}
	
}

// move even friend ahead
void DefaultChaseBlob_Moba(CBlob@ blob, CBlob @target)
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
		Repath(brain);
		blob.set_Vec2f("last pathing pos", targetPos);
	}

	const bool stuck = brain.getState() == CBrain::stuck;

	const CBrain::BrainState state = brain.getState();
	{
		//if (!isFriendAheadOfMe(blob, target))
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
				Repath(brain);
				break;

			case CBrain::searching:
				//if (sv_test)
				//	set_emote( blob, "dots" );
				break;

			case CBrain::stuck:
				Repath(brain);
				break;

			case CBrain::wrong_path:
				Repath(brain);
				break;
		}
	}

	// face the enemy
	blob.setAimPos(target.getPosition());

	// jump over small blocks
	JumpOverObstacles(blob);
}

void SearchTarget_Moba(CBrain@ this, const bool seeThroughWalls = false, const bool seeBehindBack = true)
{
	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// search target if none

	if (target is null)
	{
		CBlob@ oldTarget = target;
		@target = getBuildTarget(this, blob, seeThroughWalls, seeBehindBack);
		this.SetTarget(target);

		if (target !is oldTarget)
		{
			onChangeTarget(blob, target, oldTarget);
		}
	}
}

bool nextToHall(CBlob@ blob)
{
	CBlob@[] players;
	Vec2f pos = blob.getPosition();
	CMap@ map = blob.getMap();
	map.getBlobsInRadius(pos, 0.1f, @players);
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		if(potential.hasTag("bed") && potential.getTeamNum() != blob.getTeamNum())
		{
			return true;
		}
	}
	return false;
	
}
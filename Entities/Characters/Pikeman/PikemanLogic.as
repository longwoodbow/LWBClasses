// Pikeman logic

#include "PikemanCommon.as"
#include "ThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "EmotesCommon.as";
#include "RedBarrierCommon.as"

//attacks limited to the one time per-actor before reset.

void pikeman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool pikeman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 pikeman_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void pikeman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void pikeman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	PikemanInfo pikeman;
	this.set("pikemanInfo", @pikeman);

	pikeman.state = PikemanStates::normal;
	pikeman.pikeTimer = 0;
	pikeman.tileDestructionLimiter = 0;
	pikeman.decrease = false;
	pikeman.isSlash = false;

	this.set("pikemanInfo", @pikeman);
	
	PikemanState@[] states;
	states.push_back(NormalState());
	states.push_back(PikeDrawnState());
	states.push_back(CutState(PikemanStates::pike_cut_mid));
	states.push_back(CutState(PikemanStates::pike_cut_mid_down));
	states.push_back(CutState(PikemanStates::pike_cut_up));
	states.push_back(CutState(PikemanStates::pike_cut_down));
	states.push_back(SlashState(PikemanStates::pike_thrust));
	states.push_back(SlashState(PikemanStates::pike_thrust_super));
	states.push_back(SlashState(PikemanStates::pike_slash));
	states.push_back(ResheathState(PikemanStates::resheathing_cut, PikemanVars::resheath_cut_time));
	states.push_back(ResheathState(PikemanStates::resheathing_thrust, PikemanVars::resheath_thrust_time));
	states.push_back(ResheathState(PikemanStates::resheathing_slash, PikemanVars::resheath_slash_time));

	this.set("pikemanStates", @states);
	this.set_s32("currentPikemanState", 0);

	this.set_f32("gib health", -1.5f);
	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	pikeman_actorlimit_setup(this);
	this.Tag("player");
	this.Tag("flesh");

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	AddIconToken("$Pike$", "LWBHelpIcons.png", Vec2f(16, 16), 15);
/*
	SetHelp(this, "help self action", "pikeman", getTranslatedString("$Pike$Pike        $LMB$"), "", 255);
	SetHelp(this, "help self hide", "pikeman", getTranslatedString("Hide    $KEY_S$"), "", 255);
	SetHelp(this, "help self action2", "pikeman", getTranslatedString("$Grapple$ Grappling hook    $RMB$"), "", 255);
*/
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 15, Vec2f(16, 16));
	}
}

void RunStateMachine(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
{
	PikemanState@[]@ states;
	if (!this.get("pikemanStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentPikemanState");

	if (getNet().isClient())
	{
		if (this.exists("serverPikemanState"))
		{
			s32 serverStateIndex = this.get_s32("serverPikemanState");
			this.set_s32("serverPikemanState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				PikemanState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= PikemanStates::pike_cut_mid && net_state <= PikemanStates::pike_slash)
					{
						if ((getGameTime() - serverState.stateEnteredTime) > 20)
						{
							if (pikeman.state != PikemanStates::pike_drawn && pikeman.state != PikemanStates::resheathing_cut && pikeman.state != PikemanStates::resheathing_thrust && pikeman.state != PikemanStates::resheathing_slash)
							{
								pikeman.state = net_state;
								serverState.stateEnteredTime = getGameTime();
								serverState.StateEntered(this, pikeman, serverState.getStateValue());
								this.set_s32("currentPikemanState", serverStateIndex);
								currentStateIndex = serverStateIndex;
							}
						}

					}
				}
				else
				{
					pikeman.state = net_state;
					serverState.stateEnteredTime = getGameTime();
					serverState.StateEntered(this, pikeman, serverState.getStateValue());
					this.set_s32("currentPikemanState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = pikeman.state;
	PikemanState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, pikeman, moveVars);

	if (state != pikeman.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == pikeman.state)
			{
				s32 nextStateIndex = i;
				PikemanState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, pikeman, nextState.getStateValue());
				nextState.StateEntered(this, pikeman, currentState.getStateValue());
				this.set_s32("currentPikemanState", nextStateIndex);
				if (getNet().isServer() && pikeman.state >= PikemanStates::pike_drawn && pikeman.state <= PikemanStates::pike_slash)
				{
					this.set_s32("serverPikemanState", nextStateIndex);
					this.Sync("serverPikemanState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, pikeman, moveVars);

				}
				break;
			}
		}
	}
}

void onTick(CBlob@ this)
{
	PikemanInfo@ pikeman;
	if (!this.get("pikemanInfo", @pikeman))
	{
		return;
	}

	const bool myplayer = this.isMyPlayer();

	if(myplayer)
	{
		// description
		/*
		if (u_showtutorial && !this.hasTag("spoke description"))
		{
			this.maxChatBubbleLines = 255;
			this.Chat("Quick melee duel!\n\n[LMB] to jab/slash\n[RMB] to grapple");
			this.set_u8("emote", Emotes::off);
			this.set_u32("emotetime", getGameTime() + 300);
			this.Tag("spoke description");
		}
		*/

		// space
		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}

		// help
		/*
		if (this.isKeyJustPressed(key_action1) && getGameTime() > 150)
		{
			SetHelp(this, "help self action", "pikeman", getTranslatedString("$Help_PikePower$ Slash!    $KEY_HOLD$$LMB$"), "", 255);
		}
		else if (this.isKeyJustPressed(key_action2) && getGameTime() > 150)
		{
			SetHelp(this, "help self action", "pikeman", getTranslatedString("$Help_PikeThrow$ Throw!    $KEY_HOLD$$RMB$"), "", 255);
		}
		*/
	}

	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//pikeman logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		pikeman.state = 0;
		pikeman.pikeTimer = 0;
		pikeman.decrease = false;
		pikeman.isSlash = false;
		hud.SetCursorFrame(0);
		this.set_s32("currentPikemanState", 0);
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool pikeState = isPikeState(pikeman.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	if (getNet().isClient() && !this.isInInventory() && myplayer)  //Pikeman charge cursor
	{
		PikeCursorUpdate(this, pikeman);
	}

	if (knocked)
	{
		pikeman.state = PikemanStates::normal; //cancel any attacks or shielding
		pikeman.pikeTimer = 0;
		pikeman.decrease = false;
		pikeman.isSlash = false;
		this.set_s32("currentPikemanState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
	{
		RunStateMachine(this, pikeman, moveVars);

	}


	if (!pikeState && getNet().isServer())
	{
		pikeman_clear_actor_limits(this);
	}
}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

class NormalState : PikemanState
{
	u8 getStateValue() { return PikemanStates::normal; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state)
	{
		pikeman.pikeTimer = 0;
		this.set_u8("pikeSheathPlayed", 0);
		this.set_u8("animePikePlayed", 0);
	}

	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action1))
		{
			pikeman.state = PikemanStates::pike_drawn;
			pikeman.isSlash = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			pikeman.state = PikemanStates::pike_drawn;
			pikeman.isSlash = true;
			return true;
		}

		return false;
	}
}


s32 getPikeTimerDelta(PikemanInfo@ pikeman, bool decrease = false)
{
	s32 delta = pikeman.pikeTimer;
	if (pikeman.pikeTimer < 128 && !decrease)
	{
		pikeman.pikeTimer++;
	}
	else if (pikeman.pikeTimer > 0 && decrease)
	{
		pikeman.pikeTimer--;
	}
	return delta;
}

void AttackMovement(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	if (pikeman.isSlash)
	{
		bool strong = (pikeman.pikeTimer > PikemanVars::slash_charge);
		moveVars.jumpFactor *= (strong ? 0.5f : 0.7f);
		moveVars.walkFactor *= (strong ? 0.5f : 0.7f);
	}
	else
	{
		bool strong = (pikeman.pikeTimer > PikemanVars::thrust_charge_level2);
		moveVars.jumpFactor *= (strong ? 0.6f : 0.8f);
		moveVars.walkFactor *= (strong ? 0.8f : 0.9f);
	}

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class PikeDrawnState : PikemanState
{
	u8 getStateValue() { return PikemanStates::pike_drawn; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state)
	{
		pikeman.pikeTimer = 0;
		pikeman.decrease = false;
		this.set_u8("pikeSheathPlayed", 0);
		this.set_u8("animePikePlayed", 0);
	}

	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			pikeman.state = PikemanStates::normal;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (pikeman.isSlash)
		{
			if (getNet().isClient())
			{
				const bool myplayer = this.isMyPlayer();
				if (pikeman.pikeTimer == PikemanVars::slash_charge)
				{
					Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
					this.set_u8("pikeSheathPlayed", 0);
				}
			}
		
			if (pikeman.pikeTimer >= PikemanVars::slash_charge_limit)// begin discharging, other classes will be knocked when at the time like it
			{
				pikeman.pikeTimer = PikemanVars::slash_charge;
				pikeman.decrease = true;
			}
			else if (pikeman.pikeTimer == 0)
			{
				pikeman.decrease = false;
			}
		
			AttackMovement(this, pikeman, moveVars);
			s32 delta = getPikeTimerDelta(pikeman, pikeman.decrease);
		
			if (!this.isKeyPressed(key_action2))
			{
				if (delta < PikemanVars::slash_charge)
				{
					Vec2f vec;
					const int direction = this.getAimDirection(vec);

					if (direction == -1)
					{
						pikeman.state = PikemanStates::pike_cut_up;
					}
					else if (direction == 0)
					{
						Vec2f aimpos = this.getAimPos();
						Vec2f pos = this.getPosition();
						if (aimpos.y < pos.y)
						{
							pikeman.state = PikemanStates::pike_cut_mid;
						}
						else
						{
							pikeman.state = PikemanStates::pike_cut_mid_down;
						}
					}
					else
					{
						pikeman.state = PikemanStates::pike_cut_down;
					}
				}
				else// if(delta < PikemanVars::slash_charge_limit)
				{
					pikeman.state = PikemanStates::pike_slash;
				}
			}
		}
		else
		{
			if (getNet().isClient())
			{
				const bool myplayer = this.isMyPlayer();
				if (pikeman.pikeTimer == PikemanVars::thrust_charge_level2)
				{
					Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
					this.set_u8("animePikePlayed", 1);
				}
				else if (pikeman.pikeTimer == PikemanVars::thrust_charge)
				{
					Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
					this.set_u8("pikeSheathPlayed", 1);
				}
			}
		
			if (pikeman.pikeTimer >= PikemanVars::thrust_charge_limit)
			{
				Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
				setKnocked(this, 15);
				pikeman.state = PikemanStates::normal;
			}

			AttackMovement(this, pikeman, moveVars);
			s32 delta = getPikeTimerDelta(pikeman, false);
		
			if (!this.isKeyPressed(key_action1))
			{
				if (delta < PikemanVars::thrust_charge)
				{
					Vec2f vec;
					const int direction = this.getAimDirection(vec);

					if (direction == -1)
					{
						pikeman.state = PikemanStates::pike_cut_up;
					}
					else if (direction == 0)
					{
						Vec2f aimpos = this.getAimPos();
						Vec2f pos = this.getPosition();
						if (aimpos.y < pos.y)
						{
							pikeman.state = PikemanStates::pike_cut_mid;
						}
						else
						{
							pikeman.state = PikemanStates::pike_cut_mid_down;
						}
					}
					else
					{
						pikeman.state = PikemanStates::pike_cut_down;
					}
				}
				else if (delta < PikemanVars::thrust_charge_level2)
				{
					pikeman.state = PikemanStates::pike_thrust;
				}
				else if(delta < PikemanVars::thrust_charge_limit)
				{
					pikeman.state = PikemanStates::pike_thrust_super;
				}
			}
		}
		return false;
	}
}

class CutState : PikemanState
{
	u8 state;
	CutState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state)
	{
		pikeman_clear_actor_limits(this);
		pikeman.pikeTimer = 0;
	}

	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			pikeman.state = PikemanStates::normal;
			return false;

		}

		this.Tag("prevent crouch");

		AttackMovement(this, pikeman, moveVars);
		s32 delta = getPikeTimerDelta(pikeman);

		if (delta == DELTA_BEGIN_THRUST)
		{
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_THRUST && delta < DELTA_END_THRUST)
		{
			f32 attackarc = 90.0f;
			f32 attackAngle = getCutAngle(this, pikeman.state);

			if (pikeman.state == PikemanStates::pike_cut_down)
			{
				attackarc *= 0.9f;
			}

			DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::pike_thrust, delta, pikeman);
		}
		else if (delta >= 9)
		{
			pikeman.state = PikemanStates::resheathing_cut;
		}

		return false;

	}
}

Vec2f getSlashDirection(CBlob@ this)
{
	Vec2f vel = this.getVelocity();
	Vec2f aiming_direction = vel;
	aiming_direction.y *= 2;
	aiming_direction.Normalize();

	return aiming_direction;
}

class SlashState : PikemanState
{
	u8 state;
	SlashState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state)
	{
		pikeman_clear_actor_limits(this);
		pikeman.pikeTimer = 0;
		pikeman.slash_direction = getSlashDirection(this);
	}

	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
	{
		bool isSlash = pikeman.isSlash;

		if (moveVars.wallsliding)
		{
			pikeman.state = PikemanStates::normal;
			return false;

		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (pikeman.state == PikemanStates::pike_power_super && this.get_u8("animePikePlayed") == 0)
			{
				Sound::Play("AnimePike.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animePikePlayed", 1);
				this.set_u8("pikeSheathPlayed", 1);

			}
			else if (pikeman.state == PikemanStates::pike_power && this.get_u8("pikeSheathPlayed") == 0)
			{
				Sound::Play("PikeSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("pikeSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, pikeman, moveVars);
		s32 delta = getPikeTimerDelta(pikeman, false);

		if (pikeman.state == PikemanStates::pike_thrust_super
			&& this.isKeyJustPressed(key_action1))
		{
			pikeman.doubleslash = true;
		}

		if (delta == (isSlash ? 3 : 2))
		{
			Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > (isSlash ? DELTA_BEGIN_SLASH : DELTA_BEGIN_THRUST) && delta < (isSlash ? DELTA_END_SLASH : DELTA_END_THRUST))
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, isSlash ? 3.0f : 2.0f, -(vec.Angle()), isSlash ? 120.0f : 60.0f, isSlash ? Hitters::pike_slash : Hitters::pike_thrust, delta, pikeman);
		}
		else if (delta >= PikemanVars::thrust_time
			|| (pikeman.doubleslash && delta >= PikemanVars::double_thrust_time))
		{
			if (pikeman.doubleslash)
			{
				pikeman.doubleslash = false;
				pikeman.state = PikemanStates::pike_thrust;
			}
			else
			{
				pikeman.state = isSlash ? PikemanStates::resheathing_slash : PikemanStates::resheathing_thrust;
			}
		}

		Vec2f vel = this.getVelocity();
		if ((pikeman.state == PikemanStates::pike_thrust ||
				pikeman.state == PikemanStates::pike_thrust_super ||
				pikeman.state == PikemanStates;;pike_slash) &&
				delta < PikemanVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < PikemanVars::slash_move_max_speed &&
					vel.y > -PikemanVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  pikeman.slash_direction * this.getMass() * (isSlash ? 0.75f : 0.65f);//from 0.5f
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ResheathState : PikemanState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state)
	{
		pikeman.pikeTimer = 0;
		this.set_u8("pikeSheathPlayed", 0);
		this.set_u8("animePikePlayed", 0);
	}

	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			pikeman.state = PikemanStates::normal;
			return false;

		}
		if (this.isKeyPressed(key_action1))
		{
			pikeman.state = PikemanStates::pike_drawn;
			pikeman.isSlash = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			pikeman.state = PikemanStates::pike_drawn;
			pikeman.isSlash = true;
			return true;
		}

		AttackMovement(this, pikeman, moveVars);
		s32 delta = getPikeTimerDelta(pikeman);

		if (delta > time)
		{
			pikeman.state = PikemanStates::normal;
		}

		return false;
	}
}

void PikeCursorUpdate(CBlob@ this, PikemanInfo@ pikeman)
{
		if (!pikeman.isSlash && (pikeman.pikeTimer >= PikemanVars::thrust_charge_level2 || pikeman.doubleslash || pikeman.state == PikemanStates::pike_thrust_super))
		{
			getHUD().SetCursorFrame(19);
		}
		else if (!pikeman.isSlash && pikeman.pikeTimer >= PikemanVars::thrust_charge)
		{
			int frame = 1 + int((float(pikeman.pikeTimer - PikemanVars::thrust_charge) / (PikemanVars::thrust_charge_level2 - PikemanVars::thrust_charge)) * 9) * 2;
			getHUD().SetCursorFrame(frame);
		}
		else if (pikeman.isSlash && pikeman.pikeTimer >= PikemanVars::slash_charge)
		{
			getHUD().SetCursorFrame(1);
		}
		// the yellow circle stays for the duration of a slash, helpful for newplayers (note: you cant attack while its yellow)
		else if (pikeman.state == PikemanStates::normal || pikeman.state == PikemanStates::resheathing_cut || pikeman.state == PikemanStates::resheathing_slash || pikeman.state == PikemanStates::resheathing_thrust) // disappear after slash is done
		// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
		// else if (pikeman.pikeTimer == 0) (disappear right after mouse release)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (pikeman.pikeTimer < (pikeman.isSlash ? PikemanVars::slash_charge : PikemanVars::thrust_charge) && pikeman.state == PikemanStates::pike_drawn)
		{
			int frame = (2 + int((float(pikeman.pikeTimer) / (pikeman.isSlash ? PikemanVars::slash_charge : PikemanVars::thrust_charge)) * 8) * 2);
			if (pikeman.pikeTimer <= PikemanVars::resheath_cut_time) //prevent from appearing when jabbing/jab spamming
			{
				getHUD().SetCursorFrame(0);
			}
			else
			{
				getHUD().SetCursorFrame(frame);
			}
		}
}

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, PikemanInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	const bool jab = isJab(damage);
	bool dontHitMoreLogs = false;
	bool isSlash = type == Hitters::pike_slash;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		// start from furthest ones to avoid doing too many redundant raycasts
		for (int i = hitInfos.size() - 1; i >= 0; i--)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b !is null)
			{
				if (b.hasTag("ignore sword") 
				    || !canHit(this, b)
				    || pikeman_has_hit_actor(this, b)) 
				{
					continue;
				}

				Vec2f hitvec = hi.hitpos - pos;

				// we do a raycast to given blob and hit everything hittable between knight and that blob
				// raycast is stopped if it runs into a "large" blob (typically a door)
				// raycast length is slightly higher than hitvec to make sure it reaches the blob it's directed at
				HitInfo@[] rayInfos;
				map.getHitInfosFromRay(pos, -(hitvec).getAngleDegrees(), hitvec.Length() + 2.0f, this, rayInfos);

				for (int j = 0; j < rayInfos.size(); j++)
				{
					CBlob@ rayb = rayInfos[j].blob;
					
					if (rayb is null) break; // means we ran into a tile, don't need blobs after it if there are any
					if (rayb.hasTag("ignore sword") || !canHit(this, rayb)) continue;

					bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
								 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms
								 
					if (pikeman_has_hit_actor(this, rayb)) 
					{
						// check if we hit any of these on previous ticks of slash
						if (large) break;
						if (rayb.getName() == "log")
						{
							dontHitMoreLogs = true;
						}
						continue;
					}

					f32 temp_damage = b.hasTag("flesh") ? damage : damage / 2;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							temp_damage /= isSlash ? 2 : 3;
							dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
							CBlob@ wood = server_CreateBlobNoInit("mat_wood");
							if (wood !is null)
							{
								int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
								int max_quantity = rayb.getHealth() / 0.024f; // initial log health / max mats
								
								quantity = Maths::Max(
									Maths::Min(quantity, max_quantity),
									0
								);

								wood.Tag('custom quantity');
								wood.Init();
								wood.setPosition(rayInfos[j].hitpos);
								wood.server_SetQuantity(quantity);
							}
						}
						else 
						{
							// print("passed a log on " + getGameTime());
							continue; // don't hit the log
						}
					}
					
					pikeman_add_actor_limit(this, rayb);

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, type, true);
					}
					
					if (large)
					{
						break; // don't raycast past the door after we do damage to it
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap && (deltaInt == (isSlash ? DELTA_BEGIN_SLASH : DELTA_BEGIN_THRUST) + 1))
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile);
					bool dirt_thick_stone = map.isTileThickStone(hi.tile);
					bool gold = map.isTileGold(hi.tile);
					bool wood = map.isTileWood(hi.tile);
					bool stone = map.isTileCastle(hi.tile);
					if (ground || wood || dirt_stone || gold || stone)
					{
						Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
						Vec2f offset = (tpos - blobPos);
						f32 tileangle = offset.Angle();
						f32 dif = Maths::Abs(exact_aimangle - tileangle);
						if (dif > 180)
							dif -= 360;
						if (dif < -180)
							dif += 360;

						dif = Maths::Abs(dif);
						//print("dif: "+dif);

						if (dif < 20.0f)
						{
							//detect corner

							int check_x = -(offset.x > 0 ? -1 : 1);
							int check_y = -(offset.y > 0 ? -1 : 1);
							if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
							        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
								continue;

							bool canhit = true; //default true if not jab

							info.tileDestructionLimiter++; //fake damage
							if (!jab) //double damage on slash
							{
								info.tileDestructionLimiter++;
							}

							canhit = ((info.tileDestructionLimiter >= ((wood || dirt_stone) ? 3 : 2)));

							canhit = canhit && (isSlash || !stone);

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;
							if (canhit)
							{
								info.tileDestructionLimiter = 0;
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								if (gold)
								{
									// Note: 0.1f damage doesn't harvest anything I guess
									// This puts it in inventory - include MaterialCommon
									//Material::fromTile(this, hi.tile, 1.f);

									CBlob@ ore = server_CreateBlobNoInit("mat_gold");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
	     								ore.Init();
	     								ore.setPosition(hi.hitpos);
	     								ore.server_SetQuantity(4);
	     							}
								}
								else if (dirt_stone)
								{
									int quantity = 4;
									if(dirt_thick_stone)
									{
										quantity = 6;
									}
									CBlob@ ore = server_CreateBlobNoInit("mat_stone");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
										ore.Init();
										ore.setPosition(hi.hitpos);
										ore.server_SetQuantity(quantity);
									}
								}
								else if (isSlash && wood)
								{
									map.server_DestroyTile(hi.hitpos, 0.1f, this);
								}
							}
						}
					}
				}
		}
	}

	// destroy grass

	if (((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
	        (deltaInt == (isSlash ? DELTA_BEGIN_SLASH : DELTA_BEGIN_THRUST) + 1)) // hit only once
	{
		f32 tilesize = map.tilesize;
		int steps = Maths::Ceil(2 * radius / tilesize);
		int sign = this.isFacingLeft() ? -1 : 1;

		for (int y = 0; y < steps; y++)
			for (int x = 0; x < steps; x++)
			{
				Vec2f tilepos = blobPos + Vec2f(x * tilesize * sign, y * tilesize);
				TileType tile = map.getTile(tilepos).type;

				if (map.isTileGrass(tile))
				{
					map.server_DestroyTile(tilepos, damage, this);

					if (damage <= 1.0f)
					{
						return;
					}
				}
			}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	PikemanInfo@ pikeman;
	if (!this.get("pikemanInfo", @pikeman))
	{
		return;
	}

	if (customData == Hitters::pike_thrust &&
	        ( //is a jab - note we dont have the dmg in here at the moment :/
	            pikeman.state == PikemanStates::pike_cut_mid ||
	            pikeman.state == PikemanStates::pike_cut_mid_down ||
	            pikeman.state == PikemanStates::pike_cut_up ||
	            pikeman.state == PikemanStates::pike_cut_down
	        )
	        && blockAttack(hitBlob, velocity, 0.0f))
	{
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		setKnocked(this, 20, true);
	}
}

// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;
	
	// don't hit picked up items (except players and specially tagged items)
	return b.hasTag("player") || b.hasTag("slash_while_in_hand") || !isBlobBeingCarried(b);
}

bool isBlobBeingCarried(CBlob@ b)
{	
	CAttachment@ att = b.getAttachments();
	if (att is null)
	{
		return false;
	}

	// Look for a "PICKUP" attachment point where socket=false and occupied=true
	return att.getAttachmentPoint("PICKUP", false, true) !is null;
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @ap)
{
	if (!ap.socket) {
		PikemanInfo@ pikeman;
		if (!this.get("pikemanInfo", @pikeman))
		{
			return;
		}

		pikeman.state = PikemanStates::normal; //cancel any attacks or shielding
		pikeman.pikeTimer = 0;
		this.set_s32("currentPikemanState", 0);
	}
}

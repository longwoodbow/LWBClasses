namespace PikemanVars
{
	const ::s32 resheath_cut_time = 2;
	const ::s32 resheath_thrust_time = 2;
	const ::s32 resheath_slash_time = 2;

	const ::s32 thrust_charge = 15;
	const ::s32 thrust_charge_level2 = 38;
	const ::s32 thrust_charge_limit = thrust_charge_level2 + thrust_charge + 10;
	const ::s32 thrust_move_time = 4;
	const ::s32 thrust_time = 13;
	const ::s32 double_thrust_time = 8;

	const ::s32 slash_charge = 22;
	const ::s32 slash_charge_limit = slash_charge + 30;
	const ::s32 slash_move_time = 4;
	const ::s32 slash_time = 17;

	const ::f32 slash_move_max_speed = 7.0f;//from 3.5
}

namespace PikemanStates
{
	enum States
	{
		normal = 0,
		pike_drawn,
		pike_cut_mid,
		pike_cut_mid_down,
		pike_cut_up,
		pike_cut_down,
		pike_thrust,
		pike_thrust_super,
		pike_slash,
		resheathing_cut,
		resheathing_thrust,
		resheathing_slash
	}
}

shared class PikemanInfo
{
	u8 pikeTimer;
	bool doubleslash;
	u8 tileDestructionLimiter;
	u8 state;
	Vec2f slash_direction;
	bool decrease;
	bool isSlash;
};

shared class PikemanState
{
	u32 stateEnteredTime = 0;

	PikemanState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, PikemanInfo@ pikeman, u8 previous_state) {}
	// set knight.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, PikemanInfo@ pikeman, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, PikemanInfo@ pikeman, u8 next_state) {}
}

//checking state stuff

bool isPikeState(u8 state)
{
	return (state >= PikemanStates::pike_drawn && state <= PikemanStates::resheathing_slash);
}

bool inMiddleOfAttack(u8 state)
{
	return (state > PikemanStates::pike_drawn && state <= PikemanStates::pike_slash);
}

//checking angle stuff

f32 getCutAngle(CBlob@ this, u8 state)
{
	f32 attackAngle = (this.isFacingLeft() ? 180.0f : 0.0f);

	if (state == PikemanStates::pike_cut_mid)
	{
		attackAngle += (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == PikemanStates::pike_cut_mid_down)
	{
		attackAngle -= (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == PikemanStates::pike_cut_up)
	{
		attackAngle += (this.isFacingLeft() ? 80.0f : -80.0f);
	}
	else if (state == PikemanStates::pike_cut_down)
	{
		attackAngle -= (this.isFacingLeft() ? 80.0f : -80.0f);
	}

	return attackAngle;
}

f32 getCutAngle(CBlob@ this)
{
	Vec2f aimpos = this.getMovement().getVars().aimpos;
	int tempState;
	Vec2f vec;
	int direction = this.getAimDirection(vec);

	if (direction == -1)
	{
		tempState = PikemanStates::pike_cut_up;
	}
	else if (direction == 0)
	{
		if (aimpos.y < this.getPosition().y)
		{
			tempState = PikemanStates::pike_cut_mid;
		}
		else
		{
			tempState = PikemanStates::pike_cut_mid_down;
		}
	}
	else
	{
		tempState = PikemanStates::pike_cut_down;
	}

	return getCutAngle(this, tempState);
}

//shared attacking/bashing constants (should be in PikemanVars but used all over)

const int DELTA_BEGIN_THRUST = 2;
const int DELTA_END_THRUST = 5;
const int DELTA_BEGIN_SLASH = 3;
const int DELTA_END_SLASH = 7;
const f32 DEFAULT_ATTACK_DISTANCE = 45.0f;//from 16
const f32 MAX_ATTACK_DISTANCE = 50.0f;//from 18
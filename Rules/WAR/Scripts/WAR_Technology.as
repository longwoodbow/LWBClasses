// added new tech.
// offset of siege side techs are moved left side, for add more techs.
#include "MakeScroll.as"
#include "MiniIconsInc.as"
#include "ClassesConfig.as";

void SetupScrolls(CRules@ this)
{
	printf("### Setting WAR Scrolls");

	SetupScrollIcons(this);

	// clear old
	// assign new

	ScrollSet _all, _super, _medium, _crappy;
	this.set("all scrolls", _all);
	this.set("crappy scrolls", _crappy);
	this.set("medium scrolls", _medium);
	this.set("super scrolls", _super);

	// we have to get ready pointers cause copying dictionary doesn't work

	ScrollSet@ all = getScrollSet("all scrolls");
	ScrollSet@ super = getScrollSet("super scrolls");
	ScrollSet@ crappy = getScrollSet("crappy scrolls");
	ScrollSet@ medium = getScrollSet("medium scrolls");

	const f32 m = 1.0f;
	const f32 t = 0.23f; //multiply research time


	//						EXPLANATION

	// def.level is the horizontal positioning (X) on the research tree
	// def.tier is the vertical positioning (Y) on the research tree
	// these are used mearily for rendering the tree

	// level 0

	{
		ScrollDef def;
		def.name = "Saw";
		def.scrollFrame = FactoryFrame::saw;
		def.level = 0.0f;
		def.tier = 0.0f;
		def.timeSecs = t * 6;
		def.connections.push_back("dinghy");
		//def.connections.push_back("mounted_bow");
		//addScrollItemsToArray( "Mill Saw", "saw", m*30, false, 1, @def.items );
		all.scrolls.set("saw", def);
	}

	{
		ScrollDef def;
		def.name = "Bakery";
		def.scrollFrame = FactoryFrame::healing;
		def.level = 0.0f;
		def.tier = 2.5f - 1 / 3.0;
		def.timeSecs = t * 12;
		def.connections.push_back("military basics");
		//	def.connections.push_back("mounted_bow");

		addScrollItemsToArray("Burger", "food", m * 10, false, 3, @def.items);
		def.items[0].customData = 6;

		all.scrolls.set("healing", def);
	}

	// level 1

	{
		ScrollDef def;
		def.name = "Dinghy";
		def.scrollFrame = FactoryFrame::dinghy;
		def.level = 1.0f;
		def.tier = 0.0f;
		def.timeSecs = t * 160;
		def.connections.push_back("longboat");
		def.connections.push_back("bomb ball");
		def.connections.push_back("warboat");
		//addScrollItemsToArray( "Dinghy", "dinghy", 	m*30, false, 1, @def.items );
		all.scrolls.set("dinghy", def);
	}

	{
		ScrollDef def;
		def.name = "Military Supplies";
		def.scrollFrame = FactoryFrame::military_basics;
		def.level = 1.0f;
		def.tier = 2.5f - 1 / 3.0;
		def.timeSecs = t * 210;

		def.connections.push_back("drill");
		def.connections.push_back("acid");
		if(ClassesConfig::knight) addScrollItemsToArray("Bombs", "mat_bombs", 	m * 5, false, 3, @def.items);
		addScrollItemsToArray("Arrows", "mat_arrows", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::spearman)addScrollItemsToArray("Spears", "mat_spears", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::assassin)addScrollItemsToArray("Smoke Balls", "mat_smokeball", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::musketman || ClassesConfig::gunner)addScrollItemsToArray("Bullets", "mat_bullets", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::medic)addScrollItemsToArray("Med Kits", "mat_medkits", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::weaponthrower)addScrollItemsToArray("Boomerangs", "mat_boomerangs", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::weaponthrower)addScrollItemsToArray("Chakrams", "mat_chakrams", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::firelancer)addScrollItemsToArray("Fire Lances", "mat_firelances", 	m * 5, false, 3, @def.items);
		//		addScrollItemsToArray( "Bread", "food", m*5, false, 1, @def.items );
		all.scrolls.set("military basics", def);
	}

	// level 2

	{
		ScrollDef def;
		def.name = "Longboat";
		def.scrollFrame = FactoryFrame::longboat;
		def.level = 2.0f;
		def.tier = -0.5f;
		def.timeSecs = t * 360;
		def.connections.push_back("mounted_bow");
		addScrollItemsToArray("Longboat", "longboat", 	m * 60, true, 2, @def.items);
		all.scrolls.set("longboat", def);
	}

	{
		ScrollDef def;
		def.name = "Bomb Ball";
		def.scrollFrame = 20;
		def.level = 2.0f;
		def.tier =  0.0f;
		def.timeSecs = t * 300;
		def.connections.push_back("bomber");
		addScrollItemsToArray("Bomb Balls", "bombball", 	m * 30, false, 3, @def.items);
		all.scrolls.set("bomb ball", def);
	}

	{
		ScrollDef def;
		def.name = "War Boat";
		def.scrollFrame = FactoryFrame::warboat;
		def.level = 2.0f;
		def.tier =  0.5f;
		def.timeSecs = t * 590;
		def.connections.push_back("catapult");
		addScrollItemsToArray("War Boat", "warboat", 	m * 60, true, 1, @def.items);
		all.scrolls.set("warboat", def);
	}

	{
		ScrollDef def;
		def.name = "Drill";
		def.scrollFrame = FactoryFrame::drill;
		def.level = 2.0f;
		def.tier = 2.5f - 2 / 3.0;
		def.timeSecs = t * 450;
		def.connections.push_back("water ammo");
		def.connections.push_back("poison");
		//addScrollItemsToArray( "Arrows", "mat_arrows", 	m*60, false, 1, @def.items );
		all.scrolls.set("drill", def);
	}

	{
		ScrollDef def;
		def.name = "Acid";
		def.scrollFrame = 19;
		def.level = 2.0f;
		def.tier = 2.5f;
		def.timeSecs = t * 450;
		def.connections.push_back("water ammo");
		def.connections.push_back("poison");
		if(ClassesConfig::medic)addScrollItemsToArray("Acid Jars", "mat_acidjar", 	m * 10, false, 1, @def.items);
		//addScrollItemsToArray( "Arrows", "mat_arrows", 	m*60, false, 1, @def.items );
		all.scrolls.set("acid", def);
	}

	// level 3

	{
		ScrollDef def;
		def.name = "Water Ammo";
		def.scrollFrame = FactoryFrame::water_ammo;
		def.level = 3.0f;
		def.tier = 2.5f - 2 / 3.0;
		def.timeSecs = t * 350;
		def.connections.push_back("explosives");
		def.connections.push_back("pyro");
		def.connections.push_back("bomb ammo");
		if(ClassesConfig::archer)addScrollItemsToArray("Water Arrows", "mat_waterarrows", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::knight)addScrollItemsToArray("Water Bombs", "mat_waterbombs", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::medic)addScrollItemsToArray("Water Jars", "mat_waterjar", 	m * 5, false, 3, @def.items);
		all.scrolls.set("water ammo", def);
	}

	{
		ScrollDef def;
		def.name = "Poison";
		def.scrollFrame = 18;
		def.level = 3.0f;
		def.tier = 2.5f;
		def.timeSecs = t * 350;
		def.connections.push_back("explosives");
		def.connections.push_back("pyro");
		def.connections.push_back("bomb ammo");
		if(ClassesConfig::archer || ClassesConfig::crossbowman)addScrollItemsToArray("Poison Arrows", "mat_poisonarrows", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::spearman)addScrollItemsToArray("Poison Spears", "mat_poisonspears", 	m * 5, false, 3, @def.items);
		if(ClassesConfig::medic)addScrollItemsToArray("Poison Jars", "mat_poisonjar", 	m * 5, false, 3, @def.items);
		all.scrolls.set("poison", def);
	}

	// now mounted bow tech is camping tech and in siege side
	{
		ScrollDef def;
		def.name = "Camping";
		def.scrollFrame = FactoryFrame::mounted_bow;
		def.level = 2.5f;
		def.tier = -0.5f;
		def.timeSecs = t * 320;
		def.connections.push_back("ballista");
		if(ClassesConfig::musketman)addScrollItemsToArray("Barricade Frames", "mat_barricades", 	m * 30, false, 1, @def.items);
		//	addScrollItemsToArray( "Mounted_Bow", "mounted_bow", m*60, true, 1, @def.items );
		all.scrolls.set("mounted_bow", def);//changed, for tech icon of description
	}

	// level 4

	{
		ScrollDef def;
		def.name = "Ballista";
		def.scrollFrame = FactoryFrame::ballista;
		def.level = 3.0f;
		def.tier = -0.5f;
		def.timeSecs = t * 650;
		def.connections.push_back("crankedgun");
		def.connections.push_back("cannon");
		addScrollItemsToArray("Ballista", "ballista", m * 60, true, 1, @def.items);
		addScrollItemsToArray("Ballista Bolts", "mat_bolts", m * 60, false, 1, @def.items);
		addScrollItemsToArray("Ballista Shells", "mat_bomb_bolts", m * 60, false, 1, @def.items);
		all.scrolls.set("ballista", def);
	}

	{
		ScrollDef def;
		def.name = "Bomber";
		def.scrollFrame = 3;
		def.level = 3.0f;
		def.tier = 0.0f;
		def.timeSecs = t * 1000;
		def.connections.push_back("crankedgun");
		def.connections.push_back("cannon");
		addScrollItemsToArray("Bomber", "bomber", 	m * 60, true, 1, @def.items);
		all.scrolls.set("bomber", def);
	}

	{
		ScrollDef def;
		def.name = "Catapult";
		def.scrollFrame = FactoryFrame::catapult;
		def.level = 3.0f;
		def.tier = 0.5f;
		def.timeSecs = t * 650;
		def.connections.push_back("crankedgun");
		def.connections.push_back("cannon");
		addScrollItemsToArray("Catapult", "catapult", 	m * 60, true, 1, @def.items);
		//addScrollItemsToArray( "Boulder", "boulder", 	m*60, false, 1, @def.items );
		all.scrolls.set("catapult", def);
	}

	{
		ScrollDef def;
		def.name = "Cranked Gun";
		def.scrollFrame = 21;
		def.level = 4.0f;
		def.tier = -0.5f;
		def.timeSecs = t * 1200;
		addScrollItemsToArray("Cranked Gun", "crankedgun", 	m * 90, true, 1, @def.items);
		all.scrolls.set("crankedgun", def);
	}

	{
		ScrollDef def;
		def.name = "Cannon";
		def.scrollFrame = 22;
		def.level = 4.0f;
		def.tier = 0.5f;
		def.timeSecs = t * 1200;
		addScrollItemsToArray("Cannon", "cannon", 	m * 90, true, 1, @def.items);
		addScrollItemsToArray("Cannon Balls", "mat_cannonballs", 	m * 90, false, 1, @def.items);
		all.scrolls.set("cannon", def);
	}

	{
		ScrollDef def;
		def.name = "Demolition";
		def.scrollFrame = FactoryFrame::explosives;
		def.level = 4.0f;
		def.tier = 1.5f;
		def.timeSecs = t * 560;
		if(ClassesConfig::knight)addScrollItemsToArray("Keg", "keg", 		m * 60, false, 1, @def.items);
		addScrollItemsToArray("Mine", "mine", m * 60, false, 2, @def.items);
		all.scrolls.set("explosives", def);
	}

	{
		ScrollDef def;
		def.name = "Pyrotechnics";
		def.scrollFrame = FactoryFrame::pyro;
		def.level = 4.0f;
		def.tier = 2.5f - 1 / 3.0;
		def.timeSecs = t * 400;
		if(ClassesConfig::archer || ClassesConfig::crossbowman)addScrollItemsToArray("Fire Arrows", "mat_firearrows", 	m * 10, false, 3, @def.items);
		if(ClassesConfig::spearman)addScrollItemsToArray("Fire Spears", "mat_firespears", 	m * 10, false, 3, @def.items);
		if(ClassesConfig::firelancer)addScrollItemsToArray("Flame Throwers", "mat_flamethrowers", 	m * 10, false, 3, @def.items);
		if(ClassesConfig::butcher)addScrollItemsToArray("Oil Bottles", "mat_cookingoils", 	m * 10, false, 3, @def.items);
		//addScrollItemsToArray( "Fire Satchel", "satchel", 		m*15, false, 1, @def.items );
		//addScrollItemsToArray( "Lantern", "lantern", 		m*30, false, 1, @def.items );
		all.scrolls.set("pyro", def);
	}

	{
		ScrollDef def;
		def.name = "Bomb Ammo";
		def.scrollFrame = FactoryFrame::expl_ammo;
		def.level = 4.0f;
		def.tier = 2.5f + 1 / 3.0;
		def.timeSecs = t * 560;
		//addScrollItemsToArray( "Bombs", "mat_bombs", 	m*5, false, 1, @def.items );
		if(ClassesConfig::archer)addScrollItemsToArray("Bomb Arrows", "mat_bombarrows", 	m * 10, false, 1, @def.items);
		if(ClassesConfig::demolitionist)addScrollItemsToArray("Bomb Boxes", "mat_bombboxes", 	m * 10, false, 1, @def.items);
		all.scrolls.set("bomb ammo", def);
	}


	//spells

	{
		ScrollDef def;
		def.name = "Scroll of Carnage";
		def.scrollFrame = FactoryFrame::magic_gib;
		def.scripts.push_back("ScrollSuddenGib.as");
		all.scrolls.set("carnage", def);
	}

	{
		ScrollDef def;
		def.name = "Scroll of Midas";
		def.scrollFrame = FactoryFrame::magic_midas;
		def.scripts.push_back("ScrollMidas.as");
		all.scrolls.set("midas", def);
	}

	{
		ScrollDef def;
		def.name = "Scroll of Drought";
		def.scrollFrame = FactoryFrame::magic_drought;
		def.scripts.push_back("ScrollDrought.as");
		all.scrolls.set("drought", def);
	}

	//TODO scroll of nature/taming

	// make crappy scrolls ----------------------------------------------------

	copyFrom(all.scrolls, "saw", crappy.scrolls);
	copyFrom(all.scrolls, "military basics", crappy.scrolls);
	copyFrom(all.scrolls, "dinghy", crappy.scrolls);

	// make medium scrolls ----------------------------------------------------

//	copyFrom( all.scrolls, "saw", medium.scrolls );
	copyFrom(all.scrolls, "drill", medium.scrolls);
	copyFrom(all.scrolls, "ballista", medium.scrolls);
	copyFrom(all.scrolls, "catapult", medium.scrolls);
	copyFrom(all.scrolls, "explosives", medium.scrolls);
	copyFrom(all.scrolls, "pyro", medium.scrolls);
	copyFrom(all.scrolls, "water ammo", medium.scrolls);
	copyFrom(all.scrolls, "longboat", medium.scrolls);
	copyFrom(all.scrolls, "warboat", medium.scrolls);
	copyFrom(all.scrolls, "poison", medium.scrolls);
	copyFrom(all.scrolls, "acid", medium.scrolls);
	copyFrom(all.scrolls, "bomb ball", medium.scrolls);
	copyFrom(all.scrolls, "mounted_bow", medium.scrolls);// it's not in vanilla kag

	// make super scrolls ----------------------------------------------------

	copyFrom(all.scrolls, "bomber", super.scrolls);
	copyFrom(all.scrolls, "crankedgun", super.scrolls);
	copyFrom(all.scrolls, "cannon", super.scrolls);
	copyFrom(all.scrolls, "carnage", super.scrolls);
	copyFrom(all.scrolls, "midas", super.scrolls);
	copyFrom(all.scrolls, "drought", super.scrolls);

	//build the name arrays
	all.names = all.scrolls.getKeys();
	crappy.names = crappy.scrolls.getKeys();
	medium.names = medium.scrolls.getKeys();
	super.names = super.scrolls.getKeys();
}

void SetupScrollIcons(CRules@ this)
{
	for (uint i = 0; i < FactoryFrame::count; i++)
	{
		AddIconToken("$scroll" + i + "$", "Scroll.png", Vec2f(16, 16), i);
	}
}


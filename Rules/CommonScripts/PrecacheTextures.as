///////////////////////////////////////////////////////////
// Precache textures
//
//	loading stuff from the textures in script is slow
//	so for now we're pawning it off on load-time
//
//	If you're going to do this for a mod, it's recommended
//	that you make your own copy and add it to the mod's gamemode
//	rather than edit this directly - re-caching stuff doesn't
//	add overhead and it avoids things getting out of sync
//

#include "RunnerTextures.as"

namespace _precache {

	int team_count = 2;
	int skin_count = 1;
	array<string> textures_names = {
		//base armour
		"archer, Archer, 32, 32",
		"knight, Knight, 32, 32",
		"builder, Builder, 32, 32",
		//capes
		"archer_cape, ArcherCape, 32, 32",
		"knight_cape, KnightCape, 32, 32",
		"builder_cape, BuilderCape, 32, 32",
		//gold
		"archer_gold, ArcherGold, 32, 32",
		"knight_gold, KnightGold, 32, 32",
		"builder_gold, BuilderGold, 32, 32",
		//new
		"crossbowman, Crossbowman, 32, 32",
		"crossbowman_cape, CrossbowmanCape, 32, 32",
		"crossbowman_gold, CrossbowmanGold, 32, 32",
		"musketman, Musketman, 32, 32",
		"musketman_cape, MusketmanCape, 32, 32",
		"musketman_gold, MusketmanGold, 32, 32",
		"spearman, Spearman, 32, 32",
		"spearman_cape, SpearmanCape, 32, 32",
		"spearman_gold, SpearmanGold, 32, 32",
		"assassin, Assassin, 32, 32",
		"assassin_cape, AssassinCape, 32, 32",
		"assassin_gold, AssassinGold, 32, 32"
		"rockthrower, Rockthrower, 32, 32",
		"rockthrower_cape, RockthrowerCape, 32, 32",
		"rockthrower_gold, RockthrowerGold, 32, 32",
		"medic, Medic, 32, 32",
		"medic_cape, MedicCape, 32, 32",
		"medic_gold, MedicGold, 32, 32",
		"weaponthrower, Weaponthrower, 32, 32",
		"weaponthrower_cape, WeaponthrowerCape, 32, 32",
		"weaponthrower_gold, WeaponthrowerGold, 32, 32",
		"firelancer, Firelancer, 32, 32",
		"firelancer_cape, FirelancerCape, 32, 32",
		"firelancer_gold, FirelancerGold, 32, 32",
		"gunner, Gunner, 32, 32",
		"gunner_cape, GunnerCape, 32, 32",
		"gunner_gold, GunnerGold, 32, 32",
		"chopper, Chopper, 32, 32",
		"chopper_cape, ChopperCape, 32, 32",
		"chopper_gold, ChopperGold, 32, 32",
		"warhammer, Warhammer, 32, 32",
		"warhammer_cape, WarhammerCape, 32, 32",
		"warhammer_gold, WarhammerGold, 32, 32",
		"duelist, Duelist, 32, 32",
		"duelist_cape, DuelistCape, 32, 32",
		"duelist_gold, DuelistGold, 32, 32",
		"warcrafter, Warcrafter, 32, 32",
		"warcrafter_cape, WarcrafterCape, 32, 32",
		"warcrafter_gold, WarcrafterGold, 32, 32",
		"butcher, Butcher, 32, 32",
		"butcher_cape, ButcherCape, 32, 32",
		"butcher_gold, ButcherGold, 32, 32",
		"demolitionist, Demolitionist, 32, 32",
		"demolitionist_cape, DemolitionistCape, 32, 32",
		"demolitionist_gold, DemolitionistGold, 32, 32"
	};

	void runner_textures()
	{
		for(int i = 0; i < textures_names.length; i++)
		{
			array<string> chunks = textures_names[i].split(", ");
			if(chunks.length < 4) {
				warn("bad texture precache definition: "+textures_names[i]);
				continue;
			}

			Vec2f framesize = Vec2f(parseInt(chunks[2]), parseInt(chunks[3]));

			RunnerTextures@ tex = fetchRunnerTexture(chunks[0], chunks[1]);
			if(tex is null) {
				warn("failed to precache texture: "+textures_names[i]);
				continue;
			}

			tex.Load(framesize);

			//loop gender
			for(int g = 0; g < 2; g++)
			{
				//loop team
				for(int t = 0; t < team_count; t++)
				{
					//loop skin
					for(int s = 0; s < skin_count; s++)
					{
						//get the texture = force precache
						string texname = getRunnerTeamTexture(tex, g, t, s);
						//(debug)
						//print("cached: "+texname);
						if(isServer())
						{
							getNet().server_KeepConnectionsAlive();
						}
					}
				}
			}
		}
	}
}

void PrecacheTextures()
{
	_precache::runner_textures();
}

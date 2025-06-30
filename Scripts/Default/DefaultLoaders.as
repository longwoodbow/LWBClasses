// added new modes.
void LoadDefaultMapLoaders()
{
	printf("############ GAMEMODE " + sv_gamemode);
	if (sv_gamemode == "TTH" || sv_gamemode == "WAR" ||
	        sv_gamemode == "tth" || sv_gamemode == "war" ||
	        sv_gamemode == "Moba" || sv_gamemode == "moba")
	{
		RegisterFileExtensionScript("Scripts/MapLoaders/LoadWarPNG.as", "png");
	}
	else if (sv_gamemode == "Challenge" || sv_gamemode == "challenge")
	{
		RegisterFileExtensionScript("Scripts/MapLoaders/LoadChallengePNG.as", "png");
	}
	else if (sv_gamemode == "TDM" || sv_gamemode == "tdm" || sv_gamemode == "AD" || sv_gamemode == "ad")
	{
		RegisterFileExtensionScript("Scripts/MapLoaders/LoadTDMPNG.as", "png");
	}
	else if (sv_gamemode == "DTS" || sv_gamemode == "dts")
	{
		RegisterFileExtensionScript("Scripts/MapLoaders/LoadDTSPNG.as", "png");
	}
	else
	{
		RegisterFileExtensionScript("Scripts/MapLoaders/LoadPNGMap.as", "png");
	}


	RegisterFileExtensionScript("Scripts/MapLoaders/GenerateFromKAGGen.as", "kaggen.cfg");
}

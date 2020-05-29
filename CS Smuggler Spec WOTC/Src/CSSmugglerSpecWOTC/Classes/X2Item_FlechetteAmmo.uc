class X2Item_FlechetteAmmo extends X2Item_DefaultAmmo;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Items;

	Items.AddItem(CreateFlechetteRounds());
	
	return Items;
}

static function X2AmmoTemplate CreateFlechetteRounds()
{
	local X2AmmoTemplate Template;

	`CREATE_X2TEMPLATE(class'X2AmmoTemplate', Template, 'FlechetteRounds');

	Template.CanBeBuilt = false;
	Template.TradingPostValue = 0;
	Template.PointsToComplete = 0;
	Template.Abilities.AddItem('FlechetteRounds');
	Template.Tier = 1;
		
	//FX Reference
	Template.GameArchetype = "Ammo_Incendiary.PJ_Incendiary";
	
	return Template;
}
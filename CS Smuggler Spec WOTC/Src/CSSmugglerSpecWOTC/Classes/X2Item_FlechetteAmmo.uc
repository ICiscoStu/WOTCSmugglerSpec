class X2Item_FlechetteAmmo extends X2Item_DefaultAmmo;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Items;

	Items.AddItem(CreateFlechetteRounds());
	
	return Items;
}

static function X2AmmoTemplate CreateFlechetteRounds()
{
	local X2AmmoTemplate	Template;
	local WeaponDamageValue DamageValue;

	`CREATE_X2TEMPLATE(class'X2AmmoTemplate', Template, 'FlechetteRounds');

	Template.CanBeBuilt = false;
	Template.TradingPostValue = 0;
	Template.PointsToComplete = 0;

	//	Unnecessary and probably wouldn't work even if 'FlechetteRounds' ability existed, which it doesn't.
	//Template.Abilities.AddItem('FlechetteRounds');
	Template.Tier = 1;

	//	Placeholder stuff just for test
	DamageValue.Damage = 5;
	DamageValue.DamageType = 'Fire';
	Template.AddAmmoDamageModifier(none, DamageValue);
	Template.TargetEffects.AddItem(class'X2StatusEffects'.static.CreateBurningStatusEffect(2, 0));
		
	//FX Reference
	Template.GameArchetype = "Ammo_Incendiary.PJ_Incendiary";
	
	return Template;
}
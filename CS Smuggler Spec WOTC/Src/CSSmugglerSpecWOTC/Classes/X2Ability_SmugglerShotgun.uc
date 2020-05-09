// This is an Unreal Script
class X2Ability_SmugglerShotgun extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	Templates.AddItem(Create_Shotgun_Charge_Attack());

	return Templates;
}

static function X2AbilityTemplate Create_Shotgun_Charge_Attack(name TemplateName = 'CS_Shotgun_Charge_Attack')
{
	local X2AbilityTemplate          Template;
	local X2AbilityCost_Ammo         AmmoCost;
	local X2AbilityCost_ActionPoints ActionPointCost;
	local X2Effect_ApplyWeaponDamage WeaponDamageEffect;

	// This will be neede for stealth
	local X2Effect_RangerStealth  StealthEffect;

	// Add Slice Ability
	Template = class'X2Ability_RangerAbilitySet'.static.AddSwordSliceAbility(TemplateName);
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stealth";

	// Change Hit Calc to Standard aim to count for shotgun fire and not Melee
	Template.AbilityToHitCalc = default.SimpleStandardAim;
	Template.AbilityToHitOwnerOnMissCalc = default.SimpleStandardAim;

	// Manually stop moving since shotgun has no start/stop fire animation
	Template.bSkipMoveStop = false;

	// Ammo setup
	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = 1;
	Template.AbilityCosts.AddItem(AmmoCost);
	Template.bAllowAmmoEffects = true;
	Template.bUseAmmoAsChargesForHUD = true;

	// Action points setup
	ActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllEffects.AddItem('SawedOffSingle_DoNotConsumeAllActionsEffect');
	Template.AbilityCosts.AddItem(ActionPointCost);	

	// Damage Effect
	WeaponDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	Template.AddTargetEffect(WeaponDamageEffect);

	return Template;
}
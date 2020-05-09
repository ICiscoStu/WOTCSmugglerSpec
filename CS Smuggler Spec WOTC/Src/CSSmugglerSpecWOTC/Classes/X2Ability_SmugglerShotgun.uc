class X2Ability_SmugglerShotgun extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	Templates.AddItem(Create_Shotgun_Charge_Attack());

	return Templates;
}

static function X2AbilityTemplate Create_Shotgun_Charge_Attack(name TemplateName = 'CS_Shotgun_Charge_Attack')
{
	local X2AbilityTemplate						Template;
	local X2AbilityCost_Ammo					AmmoCost;
	local X2AbilityCost_QuickdrawActionPoints 	ActionPointCost;
	local X2Effect_ApplyWeaponDamage			WeaponDamageEffect;
	local X2Effect_Knockback					KnockbackEffect;

	// Add Slice Ability
	Template = class'X2Ability_RangerAbilitySet'.static.AddSwordSliceAbility(TemplateName);
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_stealth";

	// Change Hit Calc to Standard aim to count for shotgun fire and not Melee
	Template.AbilityToHitCalc = default.SimpleStandardAim;
	Template.AbilityToHitOwnerOnMissCalc = default.SimpleStandardAim;

	// Manually stop moving since shotgun has no start/stop fire animation
	Template.bSkipMoveStop = false;

	// Weapon Upgrade Compatibility
	// Flag that permits action to become 'free action' via 'Hair Trigger' or similar upgrade / effects
	Template.bAllowFreeFireWeaponUpgrade = true;                                            

	// Ammo setup
	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = 1;
	Template.AbilityCosts.AddItem(AmmoCost);
	Template.bAllowAmmoEffects = true;
	Template.bUseAmmoAsChargesForHUD = true;	//	Use "charges" interface to display ammo.

	// Action points setup
	ActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllEffects.AddItem('SawedOffSingle_DoNotConsumeAllActionsEffect');
	Template.AbilityCosts.AddItem(ActionPointCost);	

	KnockbackEffect = new class'X2Effect_Knockback';
	KnockbackEffect.KnockbackDistance = 3;
	Template.AddTargetEffect(KnockbackEffect);

	Template.AbilityConfirmSound = "TacticalUI_Activate_Ability_Run_N_Gun";
	Template.ActivationSpeech = 'RunAndGun';

	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	return Template;
}
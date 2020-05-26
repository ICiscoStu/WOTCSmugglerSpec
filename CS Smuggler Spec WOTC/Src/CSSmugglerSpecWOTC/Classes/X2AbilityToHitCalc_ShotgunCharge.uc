class X2AbilityToHitCalc_ShotgunCharge extends X2AbilityToHitCalc_StandardAim;

var() bool bAlwaysHit;

function int GetWeaponRangeModifier(XComGameState_Unit Shooter, XComGameState_Unit Target, XComGameState_Item Weapon)
{
	local X2WeaponTemplate WeaponTemplate;
	local int Modifier;

	if (Shooter != none && Target != none && Weapon != none)
	{
		WeaponTemplate = X2WeaponTemplate(Weapon.GetMyTemplate());

		if (WeaponTemplate != none && WeaponTemplate.RangeAccuracy.Length >= 2)
		{
			Modifier = WeaponTemplate.RangeAccuracy[1];
		}
	}

	// `LOG("current range modifier:" @ Modifier,, 'CSSmugglerSpecWOTC --------------------------------');
	return Modifier;
}

function RollForAbilityHit(XComGameState_Ability kAbility, AvailableTarget kTarget, out AbilityResultContext ResultContext)
{

	if (bAlwaysHit)
	{
		`LOG("always hit:",, 'CSSmugglerSpecWOTC --------------------------------');
		ResultContext.HitResult = eHit_Success;
	}
	else
	{
		`LOG("use regulr roll for ability",, 'CSSmugglerSpecWOTC --------------------------------');
		super.RollForAbilityHit(kAbility, kTarget, ResultContext);
	}
}
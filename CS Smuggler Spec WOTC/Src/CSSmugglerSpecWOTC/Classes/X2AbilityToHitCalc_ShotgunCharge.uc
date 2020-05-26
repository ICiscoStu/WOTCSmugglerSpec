class X2AbilityToHitCalc_ShotgunCharge extends X2AbilityToHitCalc_StandardAim;

function int GetWeaponRangeModifier(XComGameState_Unit Shooter, XComGameState_Unit Target, XComGameState_Item Weapon)
{
	local X2WeaponTemplate WeaponTemplate;
	local int Modifier;

	if (Shooter != none && Target != none && Weapon != none)
	{
		WeaponTemplate = X2WeaponTemplate(Weapon.GetMyTemplate());

		if (WeaponTemplate != none)
		{
			Modifier = WeaponTemplate.RangeAccuracy[0];
		}
	}

	// `LOG("current range modifier:" @ Modifier,, 'CSSmugglerSpecWOTC --------------------------------');
	return Modifier;
}

function RollForAbilityHit(XComGameState_Ability kAbility, AvailableTarget kTarget, out AbilityResultContext ResultContext)
{

	// `LOG("changing stage ability to always hit:",, 'CSSmugglerSpecWOTC ---------------------------------------');
	// Always hits
	ResultContext.HitResult = eHit_Success;
}
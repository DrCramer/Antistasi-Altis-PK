// HandleDamage event handler for rebels and PvPers

params ["_unit","_part","_damage","_injurer","_projectile","_hitIndex","_instigator","_hitPoint"];

// Functionality unrelated to Antistasi revive
// Helmet popping: use _hitpoint rather than _part to work around ACE calling its fake hitpoint "head"
if (_damage >= 1 && {_hitPoint == "hithead"}) then
{
	if (random 100 < helmetLossChance) then
	{
		removeHeadgear _unit;
	};
};

if (_part == "" && _damage > 0.1) then
{
	// this will not work the same with ACE, as damage isn't accumulated
	if (!isPlayer (leader group _unit) && dam < 1.0) then
	{
		//if (_damage > 0.6) then {[_unit,_unit,_injurer] spawn A3A_fnc_chargeWithSmoke};
		if (_damage > 0.6) then {[_unit,_injurer] spawn A3A_fnc_unitGetToCover};
	};

	// Contact report generation for rebels
	if (side group _injurer == Occupants or side group _injurer == Invaders) then
	{
		// Check if unit is part of a rebel garrison
		private _marker = _unit getVariable ["markerX",""];
		if (_marker != "" && {sidesX getVariable [_marker,sideUnknown] == teamPlayer}) then
		{
			// Limit last attack var changes and task updates to once per 30 seconds
			private _lastAttackTime = garrison getVariable [_marker + "_lastAttack", -30];
			if (_lastAttackTime + 30 < serverTime) then {
				garrison setVariable [_marker + "_lastAttack", serverTime, true];
				[_marker, side group _injurer, side group _unit] remoteExec ["A3A_fnc_underAttack", 2];
			};
		};
	};
};


// Let ACE medical handle the rest (inc return value) if it's running
if (A3A_hasACEMedical) exitWith {};


private _makeUnconscious =
{
	params ["_unit", "_injurer"];
	_unit setVariable ["incapacitated",true,true];
	_unit setUnconscious true;
	_unit allowDamage false;
	if (vehicle _unit != _unit) then
	{
		moveOut _unit;
	};
	
	if (isPlayer _unit) then {
		// Func. Trying to switch command to most appropriete remain unit.
		private _switchToNextMostApproprieteUnit = {
			params ["_unit_group", "_group_owner"];
			
			if ((count _unit_group) > 0) then {
				private _medic_not_switched = true;
			
				// attempt switch control to medic
				{
					if (([_x] call A3A_fnc_isMedic) && ([_x] call A3A_fnc_canFight)) exitWith {
						selectPlayer _x;
						_unit_group joinsilent group _x;
						group _x selectLeader _x;
						_medic_not_switched = false;
						["Control Unit", "Control switched to medic."] call A3A_fnc_customHint;
					};
				} forEach _unit_group;
				
				// attempt switch control to healthiest unit
				if (_medic_not_switched) then {
					private _healthiestUnit = [_unit_group, [], { getDammage _x }, "ASCEND"] call BIS_fnc_sortBy;
					_healthiestUnit = _healthiestUnit select 0;
					
					if ([_healthiestUnit] call A3A_fnc_canFight) then {
						selectPlayer _healthiestUnit;
						_unit_group joinsilent group _healthiestUnit;
						group _healthiestUnit selectLeader _healthiestUnit;
						["Control Unit", "Control switched to healthiest unit."] call A3A_fnc_customHint;
					} else {
						selectPlayer _group_owner;
						[_group_owner] spawn A3A_fnc_respawn;
					};
				};
			};
		};

		removeAllActions _unit;
		private _unit_owner = (_unit getVariable "owner");
		private _player_group_units = (units group _unit);
		
		// player had control over subordinate unit. Trying to return control to squad leader 
		// or switching command to the next healthiest unit, if commander can't fight
		if (!isPlayer _unit_owner) then {
			// commander can fight
			if ([_unit_owner] call A3A_fnc_canFight) then {
				selectPlayer _unit_owner;
				(units group _unit) joinsilent group _unit_owner;
				group _unit_owner selectLeader _unit_owner;
				["Control Unit", "Control returned to squad leader."] call A3A_fnc_customHint;
			} else {
				[_player_group_units, _unit_owner] call _switchToNextMostApproprieteUnit;
			}
		// player played as a squad leader until it was shoot. Trying to switch command to most appropriete remain unit.
		} else {
			[_player_group_units, _unit_owner] call _switchToNextMostApproprieteUnit;
		};
	};
	
	private _fromside = if (!isNull _injurer) then {side group _injurer} else {sideUnknown};
	[_unit,_fromside] spawn A3A_fnc_unconscious;
};

if (_part == "") then
{
	if (_damage >= 1) then
	{
		if (side _injurer == civilian) then
		{
			// apparently civilians are non-lethal
			_damage = 0.9;
		}
		else
		{
			if !(_unit getVariable ["incapacitated",false]) then
			{
				_damage = 0.9;
				[_unit, _injurer] call _makeUnconscious;
			}
			else
			{
				// already unconscious, check whether we're pushed into death
				_overall = (_unit getVariable ["overallDamage",0]) + (_damage - 1);
				if (_overall > 1) then
				{
					if (isPlayer _unit) then
					{
						_damage = 0;
						[_unit] spawn A3A_fnc_respawn;
					}
					else
					{
						_unit removeAllEventHandlers "HandleDamage";
					};
				}
				else
				{
					_unit setVariable ["overallDamage",_overall];
					_damage = 0.9;
				};
			};
		};
	}
	else
	{
		if (_damage > 0.25) then
		{
			if (_unit getVariable ["helping",false]) then
			{
				_unit setVariable ["cancelRevive",true];
			};
			if (isPlayer (leader group _unit)) then
			{
				if (autoheal) then
				{
					_helped = _unit getVariable ["helped",objNull];
					if (isNull _helped) then {[_unit] call A3A_fnc_askHelp;};
				};
			};
		};
	};
}
else
{
	if (_damage >= 1) then
	{
		if !(_part in ["arms","hands","legs"]) then
		{
			_damage = 0.9;
			if (_part in ["head","body"]) then
			{
				if !(_unit getVariable ["incapacitated",false]) then
				{
					[_unit, _injurer] call _makeUnconscious;
				};
			};
		};
	};
};

_damage

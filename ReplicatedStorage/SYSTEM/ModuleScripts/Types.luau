-- MODULE
local Types = {}


export type StackData = {
	Name: string;
	Description: string;
	Image: string;
	ItemType: string;
	IsDroppable: boolean;
	Items: {Tool};
	StackId: number;
}

export type Armor = {
	Helm: number?;
	Plate: number?;
	Boots: number?;
}

export type Hotbar = {
	Slot1: number?;
	Slot2: number?;
	Slot3: number?;
	Slot4: number?;
	Slot5: number?;
	Slot6: number?;
	Slot7: number?;
	Slot8: number?;
	Slot9: number?;
	Slot10: number?;
}

export type Inventory = {
	Inventory: {StackData};
	Hotbar: Hotbar;
	Armor: { [string] : number};
	NextStackId: number;
}


return Types
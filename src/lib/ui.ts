export type UnitDisplayValue={code?:string|null;name_th?:string|null;name_en?:string|null};

const unitCodeLabel:Record<string,string>={
 G:'กรัม',GRAM:'กรัม',KG:'กิโลกรัม',KILOGRAM:'กิโลกรัม',
 ML:'มิลลิลิตร',MILLILITER:'มิลลิลิตร',L:'ลิตร',LITER:'ลิตร',
 PCS:'ชิ้น',PC:'ชิ้น',PIECE:'ชิ้น',EA:'ชิ้น',EACH:'ชิ้น',
 PACK:'แพ็ก',BAG:'ถุง',BOTTLE:'ขวด',CAN:'กระป๋อง',BOX:'กล่อง',CUP:'ถ้วย',
 TBSP:'ช้อนโต๊ะ',TSP:'ช้อนชา'
};

export function formatUnit(unit?:UnitDisplayValue|null,fallback=''){
 if(!unit)return fallback;
 const code=unit.code?.trim();
 return unit.name_th?.trim()||unitCodeLabel[code?.toUpperCase()||'']||code||unit.name_en?.trim()||fallback;
}

export function uiError(action='ดำเนินการ'){
 return `${action}ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง`;
}

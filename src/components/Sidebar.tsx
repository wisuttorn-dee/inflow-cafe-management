import { useEffect, useMemo, useState } from 'react';
import { NavLink } from 'react-router-dom';
import {
  BarChart3,
  BookOpen,
  Boxes,
  ChevronRight,
  ClipboardCheck,
  Coffee,
  FileClock,
  FileSpreadsheet,
  Gauge,
  History,
  LayoutDashboard,
  LogOut,
  MenuSquare,
  PackageSearch,
  ReceiptText,
  Settings,
  ShoppingCart,
  SlidersHorizontal,
  Tags,
  Truck,
  Users,
  WalletCards,
  Warehouse,
  XCircle,
} from 'lucide-react';
import { supabase } from '../lib/supabase';

type Role = 'OWNER' | 'MANAGER' | 'STAFF';
type NavItem = {
  label: string;
  path: string;
  icon: typeof LayoutDashboard;
  roles?: Role[];
};
type NavGroup = { label: string; items: NavItem[] };

const managementRoles: Role[] = ['OWNER', 'MANAGER'];

const navGroups: NavGroup[] = [
  {
    label: 'ภาพรวม',
    items: [
      { label: 'แดชบอร์ด', path: '/', icon: LayoutDashboard },
      { label: 'ภาพรวมยอดขาย', path: '/sales', icon: BarChart3, roles: managementRoles },
      { label: 'รายงานกำไร', path: '/reports', icon: Gauge, roles: managementRoles },
    ],
  },
  {
    label: 'การขาย',
    items: [
      { label: 'รายการขาย', path: '/sales/transactions', icon: ReceiptText },
      { label: 'นำเข้า GPOS', path: '/sales/import', icon: FileSpreadsheet },
      { label: 'ประวัตินำเข้า', path: '/sales/import-history', icon: FileClock },
    ],
  },
  {
    label: 'สินค้าและสูตร',
    items: [
      { label: 'เมนูสินค้า', path: '/menu', icon: MenuSquare, roles: managementRoles },
      { label: 'สูตรเครื่องดื่ม', path: '/recipes', icon: BookOpen, roles: managementRoles },
      { label: 'ต้นทุนสูตร', path: '/recipe-costing', icon: WalletCards, roles: managementRoles },
    ],
  },
  {
    label: 'สต็อก',
    items: [
      { label: 'ภาพรวมสต็อก', path: '/inventory', icon: Warehouse },
      { label: 'ความเคลื่อนไหว', path: '/inventory/movements', icon: History },
      { label: 'ตรวจนับสต็อก', path: '/inventory/count', icon: ClipboardCheck },
      { label: 'บันทึกของเสีย', path: '/inventory/waste', icon: XCircle },
      { label: 'วัตถุดิบใกล้หมด', path: '/inventory/low', icon: PackageSearch },
    ],
  },
  {
    label: 'จัดซื้อและค่าใช้จ่าย',
    items: [
      { label: 'จัดซื้อ', path: '/purchasing', icon: ShoppingCart },
      { label: 'ซัพพลายเออร์', path: '/suppliers', icon: Truck, roles: managementRoles },
      { label: 'ค่าใช้จ่าย', path: '/expenses', icon: ReceiptText },
    ],
  },
  {
    label: 'ข้อมูลหลักและระบบ',
    items: [
      { label: 'วัตถุดิบ', path: '/ingredients', icon: Boxes, roles: managementRoles },
      { label: 'หน่วยนับ', path: '/settings/units', icon: SlidersHorizontal, roles: managementRoles },
      { label: 'หมวดเมนู', path: '/settings/categories', icon: Tags, roles: managementRoles },
      { label: 'ผู้ใช้งาน', path: '/settings/users', icon: Users, roles: ['OWNER'] },
      { label: 'ตั้งค่าระบบ', path: '/settings', icon: Settings, roles: managementRoles },
    ],
  },
];

export function Sidebar({ open, onNavigate }: { open: boolean; onNavigate: () => void }) {
  const [role, setRole] = useState<Role>('STAFF');
  const [displayName, setDisplayName] = useState('ผู้ใช้งาน');
  const [email, setEmail] = useState('');

  useEffect(() => {
    void supabase.auth.getUser().then(async ({ data }) => {
      const user = data.user;
      if (!user) return;
      setEmail(user.email ?? '');
      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name,role')
        .eq('id', user.id)
        .maybeSingle();
      if (profile?.role === 'OWNER' || profile?.role === 'MANAGER' || profile?.role === 'STAFF') {
        setRole(profile.role);
      }
      setDisplayName(profile?.display_name || user.email?.split('@')[0] || 'ผู้ใช้งาน');
    });
  }, []);

  const visibleGroups = useMemo(
    () =>
      navGroups
        .map((group) => ({
          ...group,
          items: group.items.filter((item) => !item.roles || item.roles.includes(role)),
        }))
        .filter((group) => group.items.length > 0),
    [role],
  );

  return (
    <aside className={open ? 'sidebar open' : 'sidebar'}>
      <div className="sidebarBrand">
        <div className="brandMark"><Coffee size={20} strokeWidth={2.2} /></div>
        <div>
          <strong>INFLOW</strong>
          <span>Riverside Café</span>
        </div>
      </div>

      <nav className="sidebarNav" onClick={onNavigate}>
        {visibleGroups.map((group) => (
          <section className="navGroup" key={group.label}>
            <div className="navGroupLabel">{group.label}</div>
            {group.items.map((item) => {
              const Icon = item.icon;
              return (
                <NavLink key={item.path} to={item.path} end={item.path === '/'} className="navItem">
                  <Icon size={17} strokeWidth={1.9} />
                  <span>{item.label}</span>
                  <ChevronRight className="navChevron" size={14} />
                </NavLink>
              );
            })}
          </section>
        ))}
      </nav>

      <div className="sidebarFooter">
        <div className="userMiniCard">
          <div className="avatar">{displayName.slice(0, 1).toUpperCase()}</div>
          <div className="userMeta">
            <strong>{displayName}</strong>
            <span>{email}</span>
          </div>
          <span className={`roleBadge role${role}`}>{role}</span>
        </div>
        <button className="signoutButton" onClick={() => void supabase.auth.signOut()}>
          <LogOut size={16} /> ออกจากระบบ
        </button>
      </div>
    </aside>
  );
}

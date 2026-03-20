import 'package:azalia/components/widgets/adminHeader.dart';
import 'footer.dart';

const List<FooterItems> userFooterItems = [
  FooterItems(icon: 'assets/icons/Home.svg', route: '/'),
  FooterItems(icon: 'assets/icons/Love.svg', route: '/love'),
  FooterItems(icon: 'assets/icons/Bag.svg', route: '/cart'),
  FooterItems(icon: 'assets/icons/User.svg', route: '/profile'),
];

const List<FooterItems> adminFooterItems = [
  // если менять иконки то надо изменить и в footer.dart _iconFromString
  FooterItems(icon: 'analytics_outlined', route: '/admin', isSvg: false),
  FooterItems(icon: 'local_florist', route: '/admin/products', isSvg: false),
  FooterItems(icon: 'assets/icons/Home.svg', route: '/'),
  FooterItems(
    icon: 'supervised_user_circle_outlined',
    route: '/admin/users',
    isSvg: false,
  ),
  FooterItems(icon: 'workspace_premium_outlined', route: '/admin/settings', isSvg: false),
];

const List<HeaderItems> adminHeaderItems = [
  HeaderItems(route: '/admin', title: "Админ-аналитика"),
  HeaderItems(route: '/admin/products', title: "Админ-товары"),
  HeaderItems(route: '/admin/users', title: "Админ-пользователи"),
  HeaderItems(route: '/admin/settings', title: "Админ-подписки"),
];
const List<HeaderItems> adminProductsHeaderItems = [
  HeaderItems(
    route: '/admin/products/procurement',
    title: "Админ-закупки",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/warehouse',
    title: "Админ-склад",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/editor',
    title: "Админ-редактор",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/delivery',
    title: "Админ-поставки",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/orders',
    title: "Админ-заказы",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/receipts',
    title: "Админ-разгрузка",
    isButton: true,
  ),
  HeaderItems(
    route: '/admin/products/subscriptions',
    title: "Админ-подписки",
    isButton: true,
  ),
];

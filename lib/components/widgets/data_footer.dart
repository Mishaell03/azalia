import 'footer.dart';

const List<FooterItems> userFooterItems = [
  FooterItems(icon: 'assets/icons/Home.svg', route: '/'),
  FooterItems(icon: 'assets/icons/Love.svg', route: '/love'),
  FooterItems(icon: 'assets/icons/Bag.svg', route: '/cart'),
  FooterItems(icon: 'assets/icons/User.svg', route: '/profile'),
];

const List<FooterItems> adminFooterItems = [
  FooterItems(icon: 'analytics_outlined', route: '/admin', isSvg: false),
  FooterItems(icon: 'local_shipping_outlined', route: '/admin', isSvg: false),
  FooterItems(icon: 'home_filled', route: '/', isSvg: false),
  FooterItems(icon: 'supervised_user_circle_outlined', route: '/admin', isSvg: false),
  FooterItems(icon: 'settings', route: '/admin/settings', isSvg: false),
];
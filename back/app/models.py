from app import db
from datetime import datetime, timedelta
import secrets

class Position(db.Model):
    """таблицы должностей"""
    __tablename__ = 'positions'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), unique=True, nullable=False)
    responsibilities = db.Column(db.Text)
    requirements = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    employees = db.relationship('Employee', backref='position', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'responsibilities': self.responsibilities,
            'requirements': self.requirements,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Category(db.Model):
    """таблицы категорий растений"""
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text)
    parent_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    parent = db.relationship('Category', remote_side=[id], backref='subcategories')
    plants = db.relationship('PotPlant', backref='category', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'parent_id': self.parent_id,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Supplier(db.Model):
    """таблицы поставщиков"""
    __tablename__ = 'suppliers'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    address = db.Column(db.Text, nullable=False)
    contact_person = db.Column(db.String(100), nullable=False)
    staff_info = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    plants = db.relationship('PotPlant', backref='supplier', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'address': self.address,
            'contact_person': self.contact_person,
            'staff_info': self.staff_info,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
class PotMaterial(db.Model):
    """таблицы материалов горшков"""
    __tablename__ = 'pot_materials'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    pot_prices = db.relationship('PotPrice', backref='material', lazy=True)
    cart_items = db.relationship('CartItem', backref='pot_material', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class PotSize(db.Model):
    """таблицы размеров горшков"""
    __tablename__ = 'pot_sizes'
    
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(5), unique=True, nullable=False)
    name = db.Column(db.String(50), nullable=False)
    diameter_cm = db.Column(db.Integer)
    height_cm = db.Column(db.Integer)
    volume_liters = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    pot_prices = db.relationship('PotPrice', backref='size', lazy=True)
    cart_items = db.relationship('CartItem', backref='pot_size', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'code': self.code,
            'name': self.name,
            'diameter_cm': self.diameter_cm,
            'height_cm': self.height_cm,
            'volume_liters': self.volume_liters,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class PotColor(db.Model):
    """таблицы цветов горшков"""
    __tablename__ = 'pot_colors'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    hex_code = db.Column(db.String(7))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    cart_items = db.relationship('CartItem', backref='pot_color', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'hex_code': self.hex_code,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
class PotPrice(db.Model):
    """таблицы цен на горшки"""
    __tablename__ = 'pot_prices'
    
    id = db.Column(db.Integer, primary_key=True)
    material_id = db.Column(db.Integer, db.ForeignKey('pot_materials.id'), nullable=False)
    size_id = db.Column(db.Integer, db.ForeignKey('pot_sizes.id'), nullable=False)
    price = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'material_id': self.material_id,
            'size_id': self.size_id,
            'price': self.price,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'material': self.material.to_dict() if self.material else None,
            'size': self.size.to_dict() if self.size else None
        }

class PotPlant(db.Model):
    """таблицы горшечных растений"""
    __tablename__ = 'pot_plants'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text)
    base_price = db.Column(db.Float, nullable=False)
    supplier_id = db.Column(db.Integer, db.ForeignKey('suppliers.id'))
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    plant_type = db.Column(db.String(20))
    recommended_pot_size = db.Column(db.String(2))
    height_cm = db.Column(db.Integer)
    care_instructions = db.Column(db.Text)
    light_requirements = db.Column(db.String(20))
    watering_frequency = db.Column(db.String(50))
    in_stock = db.Column(db.Boolean, default=True)
    rating = db.Column(db.Float)
    image_url = db.Column(db.String(255))
    stock_quantity = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    order_items = db.relationship('OrderItem', backref='plant', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'base_price': self.base_price,
            'supplier_id': self.supplier_id,
            'category_id': self.category_id,
            'plant_type': self.plant_type,
            'recommended_pot_size': self.recommended_pot_size,
            'height_cm': self.height_cm,
            'care_instructions': self.care_instructions,
            'light_requirements': self.light_requirements,
            'watering_frequency': self.watering_frequency,
            'in_stock': self.in_stock,
            'rating': self.rating,
            'image_url': self.image_url,
            'stock_quantity': self.stock_quantity,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class User(db.Model):
    """таблицы пользователей"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    telegram_id = db.Column(db.Integer, unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    session_token = db.Column(db.String(255), unique=True)
    token_expires_at = db.Column(db.DateTime)
    avatar = db.Column(db.LargeBinary)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    orders = db.relationship('Order', backref='user', lazy=True)
    payment_links = db.relationship('PaymentLink', backref='user', lazy=True)
    reviews = db.relationship('Review', backref='user', lazy=True)
    employee_info = db.relationship('Employee', backref='user', lazy=True, uselist=False)
    
    def to_dict(self):
        avatar_base64 = None
        if self.avatar:
            try:
                import base64
                avatar_base64 = base64.b64encode(self.avatar).decode('utf-8')
            except Exception as e:
                import logging
                logging.warning(f"Error encoding avatar for user {self.id}: {e}")
                pass
        
        return {
            'id': self.id,
            'telegram_id': self.telegram_id,
            'name': self.name,
            'phone': self.phone,
            'avatar': avatar_base64,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'is_employee': self.is_employee()
        }
    
    def is_employee(self):
        """проверка, является ли пользователь сотрудником"""
        return self.employee_info is not None and self.employee_info.is_active

    @staticmethod
    def build_display_name(first_name=None, last_name=None, username=None):
        parts = []
        for value in (first_name, last_name):
            if isinstance(value, str) and value.strip():
                parts.append(value.strip())

        full_name = " ".join(parts).strip()
        if not full_name and isinstance(username, str) and username.strip():
            full_name = username.strip()
        if not full_name:
            full_name = "Пользователь"

        return full_name[:100]

    @classmethod
    def get_or_create_by_telegram(
        cls,
        telegram_id,
        first_name=None,
        last_name=None,
        username=None,
        phone="",
    ):
        user = cls.query.filter_by(telegram_id=telegram_id).first()
        if user:
            return user, False

        user = cls(
            telegram_id=telegram_id,
            name=cls.build_display_name(first_name, last_name, username),
            phone=phone if isinstance(phone, str) else "",
        )
        db.session.add(user)
        return user, True

class Employee(db.Model):
    """таблицы сотрудников"""
    __tablename__ = 'employees'
    
    id = db.Column(db.Integer, primary_key=True)
    telegram_id = db.Column(db.Integer, db.ForeignKey('users.telegram_id'), unique=True, nullable=False)
    position_id = db.Column(db.Integer, db.ForeignKey('positions.id'), nullable=False)
    salary = db.Column(db.Float)
    hire_date = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    assigned_orders = db.relationship('Order', backref='assigned_employee', lazy=True)
    status_changes = db.relationship('OrderStatusHistory', backref='employee', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'telegram_id': self.telegram_id,
            'position_id': self.position_id,
            'salary': self.salary,
            'hire_date': self.hire_date.isoformat() if self.hire_date else None,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    def to_dict_with_details(self):
        """расширенная инфа о сотруднике"""
        data = self.to_dict()
        if self.position:
            data['position'] = self.position.to_dict()
        if self.user:
            avatar_base64 = None
            if self.user.avatar:
                try:
                    import base64
                    avatar_base64 = base64.b64encode(self.user.avatar).decode('utf-8')
                except Exception as e:
                    import logging
                    logging.warning(f"Error encoding avatar for employee {self.id}: {e}")
                    pass
            
            data['user_info'] = {
                'name': self.user.name,
                'phone': self.user.phone,
                'avatar': avatar_base64
            }
        return data

class Order(db.Model):
    """таблицы заказов"""
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    order_date = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    delivery_date = db.Column(db.DateTime)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    address = db.Column(db.Text, nullable=False)
    total_price = db.Column(db.Float, nullable=False)
    payment_method = db.Column(db.String(10)) 
    is_paid = db.Column(db.Boolean, default=False)
    assigned_employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'))
    status = db.Column(db.String(20), default='new')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    order_items = db.relationship('OrderItem', backref='order', lazy=True)
    payment_links = db.relationship('PaymentLink', backref='order', lazy=True)
    status_history = db.relationship('OrderStatusHistory', backref='order', lazy=True)
    reviews = db.relationship('Review', backref='order', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_date': self.order_date.isoformat() if self.order_date else None,
            'delivery_date': self.delivery_date.isoformat() if self.delivery_date else None,
            'user_id': self.user_id,
            'address': self.address,
            'total_price': self.total_price,
            'payment_method': self.payment_method,
            'is_paid': self.is_paid,
            'assigned_employee_id': self.assigned_employee_id,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class OrderItem(db.Model):
    """таблицы позиций заказа"""
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    plant_id = db.Column(db.Integer, db.ForeignKey('pot_plants.id'), nullable=False)
    quantity = db.Column(db.Integer, default=1, nullable=False)
    plant_unit_price = db.Column(db.Float, nullable=False)
    pot_color = db.Column(db.String(20))
    pot_size = db.Column(db.String(2))
    pot_material = db.Column(db.String(20))
    pot_unit_price = db.Column(db.Float, default=0)
    total_price = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_id': self.order_id,
            'plant_id': self.plant_id,
            'quantity': self.quantity,
            'plant_unit_price': self.plant_unit_price,
            'pot_color': self.pot_color,
            'pot_size': self.pot_size,
            'pot_material': self.pot_material,
            'pot_unit_price': self.pot_unit_price,
            'total_price': self.total_price,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class PaymentLink(db.Model):
    """таблицы ссылок на оплату"""
    __tablename__ = 'payment_links'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'))
    amount = db.Column(db.Float, nullable=False)
    payment_url = db.Column(db.String, unique=True)
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime)
    payment_system_id = db.Column(db.String)
    payment_confirmed_at = db.Column(db.DateTime)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'order_id': self.order_id,
            'amount': self.amount,
            'payment_url': self.payment_url,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'payment_system_id': self.payment_system_id,
            'payment_confirmed_at': self.payment_confirmed_at.isoformat() if self.payment_confirmed_at else None
        }

class OrderStatusHistory(db.Model):
    """таблицы истории статусов заказа"""
    __tablename__ = 'order_status_history'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    old_status = db.Column(db.String(20))
    new_status = db.Column(db.String(20), nullable=False)
    changed_by = db.Column(db.Integer, db.ForeignKey('employees.id'))
    change_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'order_id': self.order_id,
            'old_status': self.old_status,
            'new_status': self.new_status,
            'changed_by': self.changed_by,
            'change_reason': self.change_reason,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Review(db.Model):
    """таблицы отзывов"""
    __tablename__ = 'reviews'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'order_id': self.order_id,
            'rating': self.rating,
            'comment': self.comment,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
class OAuthCode(db.Model):
    """хранение одноразовых кодов"""
    __tablename__ = 'oauth_codes'
    
    id = db.Column(db.Integer, primary_key=True)
    telegram_id = db.Column(db.Integer, db.ForeignKey('users.telegram_id'), nullable=False)
    device_id = db.Column(db.String(255), nullable=False)
    code = db.Column(db.String(6), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)
    used = db.Column(db.Boolean, default=False)
    used_at = db.Column(db.DateTime)
    
    user = db.relationship('User', foreign_keys=[telegram_id], primaryjoin="OAuthCode.telegram_id == User.telegram_id", backref='oauth_codes')
    
    def to_dict(self):
        return {
            'id': self.id,
            'telegram_id': self.telegram_id,
            'device_id': self.device_id,
            'code': self.code,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'used': self.used,
            'used_at': self.used_at.isoformat() if self.used_at else None
        }
    
    def is_valid(self):
        return not self.used and self.expires_at > datetime.utcnow()

    @classmethod
    def get_active_for_device(cls, telegram_id, device_id, now=None):
        check_time = now or datetime.utcnow()
        return (
            cls.query.filter_by(telegram_id=telegram_id, device_id=device_id, used=False)
            .filter(cls.expires_at > check_time)
            .order_by(cls.id.desc())
            .first()
        )

    @classmethod
    def get_for_user_by_id(cls, oauth_code_id, telegram_id):
        return cls.query.filter_by(id=oauth_code_id, telegram_id=telegram_id).first()

    @classmethod
    def generate_code(cls, length=4):
        upper_bound = 10**length
        value = secrets.randbelow(upper_bound)
        return str(value).zfill(length)

    @classmethod
    def generate_unique_active_code(cls, now=None, length=4, max_attempts=40):
        check_time = now or datetime.utcnow()
        for _ in range(max_attempts):
            code = cls.generate_code(length=length)
            exists = (
                cls.query.filter_by(code=code, used=False)
                .filter(cls.expires_at > check_time)
                .first()
            )
            if not exists:
                return code
        raise ValueError("Не удалось сгенерировать уникальный код авторизации.")

    @classmethod
    def issue_or_refresh(
        cls,
        telegram_id,
        device_id,
        ttl_minutes=10,
        force_refresh=False,
        oauth_code_id=None,
    ):
        now = datetime.utcnow()

        if not force_refresh:
            active = cls.get_active_for_device(telegram_id=telegram_id, device_id=device_id, now=now)
            if active:
                return active, False

        target = None
        if oauth_code_id is not None:
            target = cls.get_for_user_by_id(oauth_code_id=oauth_code_id, telegram_id=telegram_id)
            if target and target.device_id != device_id:
                target = None

        if target is None:
            target = (
                cls.query.filter_by(telegram_id=telegram_id, device_id=device_id)
                .order_by(cls.id.desc())
                .first()
            )

        code = cls.generate_unique_active_code(now=now, length=4)
        expires_at = now + timedelta(minutes=ttl_minutes)

        if target:
            target.code = code
            target.expires_at = expires_at
            target.used = False
            target.used_at = None
            return target, True

        oauth_code = cls(
            telegram_id=telegram_id,
            device_id=device_id,
            code=code,
            expires_at=expires_at,
            used=False,
        )
        db.session.add(oauth_code)
        return oauth_code, True
    
class CartItem(db.Model):
    """таблицы корзины пользователя"""
    __tablename__ = 'cart_items'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    plant_id = db.Column(db.Integer, db.ForeignKey('pot_plants.id'), nullable=False)
    quantity = db.Column(db.Integer, default=1, nullable=False)
    pot_color_id = db.Column(db.Integer, db.ForeignKey('pot_colors.id'))
    pot_size_id = db.Column(db.Integer, db.ForeignKey('pot_sizes.id'))
    pot_material_id = db.Column(db.Integer, db.ForeignKey('pot_materials.id'))
    plant_unit_price = db.Column(db.Float, nullable=False)
    pot_unit_price = db.Column(db.Float, default=0, nullable=False)
    total_price = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship('User', backref='cart_items')
    plant = db.relationship('PotPlant', backref='cart_items')
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'plant_id': self.plant_id,
            'quantity': self.quantity,
            'pot_color_id': self.pot_color_id,
            'pot_size_id': self.pot_size_id,
            'pot_material_id': self.pot_material_id,
            'plant_unit_price': self.plant_unit_price,
            'pot_unit_price': self.pot_unit_price,
            'total_price': self.total_price,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'plant': self.plant.to_dict() if self.plant else None,
            'pot_color': self.pot_color.to_dict() if self.pot_color else None,
            'pot_size': self.pot_size.to_dict() if self.pot_size else None,
            'pot_material': self.pot_material.to_dict() if self.pot_material else None
        }

class WishlistItem(db.Model):
    """таблицы избранного пользователя"""
    __tablename__ = 'wishlist_items'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    plant_id = db.Column(db.Integer, db.ForeignKey('pot_plants.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    user = db.relationship('User', backref='wishlist_items')
    plant = db.relationship('PotPlant', backref='wishlist_items')
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'plant_id': self.plant_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'plant': self.plant.to_dict() if self.plant else None
        }

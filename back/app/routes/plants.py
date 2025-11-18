from flask import Blueprint, request, jsonify
from app import db
from app.models import PotPlant, Category, Supplier
from sqlalchemy import or_
import os
import uuid
import re
from werkzeug.utils import secure_filename

bp = Blueprint('plants', __name__, url_prefix='/api/plants')

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
MAX_FILE_SIZE = 16 * 1024 * 1024

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def safe_filename(filename):
    """извлекает безопасное имя файла из URL"""
    if not filename:
        return None
    base_name = os.path.basename(filename)
    if re.match(r'^[a-f0-9]{32}_[a-zA-Z0-9_\-\.]+$', base_name):
        return base_name
    return None

def save_uploaded_file(file):
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        unique_filename = f"{uuid.uuid4().hex}_{filename}"
        
        img_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'img')
        os.makedirs(img_dir, exist_ok=True)
        
        file_path = os.path.join(img_dir, unique_filename)
        file.save(file_path)
        
        return unique_filename
    return None

def safe_float(value, default=None, min_val=None, max_val=None):
    """преобразование в float с валидацией"""
    if value is None:
        return default
    try:
        result = float(value)
        if min_val is not None and result < min_val:
            return default
        if max_val is not None and result > max_val:
            return default
        return result
    except (ValueError, TypeError):
        return default

def safe_int(value, default=None, min_val=None, max_val=None):
    """преобразование в int с валидацией"""
    if value is None:
        return default
    try:
        result = int(value)
        if min_val is not None and result < min_val:
            return default
        if max_val is not None and result > max_val:
            return default
        return result
    except (ValueError, TypeError):
        return default

def validate_string_input(text, max_length=255):
    """строкового ввода"""
    if not text or not isinstance(text, str):
        return None
    cleaned = re.sub(r'[<>"\']', '', text.strip())
    return cleaned[:max_length] if cleaned else None

# список растений с фильтрами
@bp.route('/', methods=['GET'], endpoint='plants_list')
def get_plants():
    try:
        category_id = safe_int(request.args.get('category_id'), min_val=1)
        in_stock = request.args.get('in_stock', type=lambda v: v.lower() == 'true')
        plant_type = validate_string_input(request.args.get('plant_type'), 20)
        search = validate_string_input(request.args.get('search'), 100)
        
        min_price = safe_float(request.args.get('min_price'), min_val=0, max_val=1000000)
        max_price = safe_float(request.args.get('max_price'), min_val=0, max_val=1000000)
        min_rating = safe_float(request.args.get('min_rating'), min_val=0, max_val=5)
        max_rating = safe_float(request.args.get('max_rating'), min_val=0, max_val=5)
    
        query = PotPlant.query

        if category_id:
            query = query.filter(PotPlant.category_id == category_id)
        
        if in_stock is not None:
            query = query.filter(PotPlant.in_stock == in_stock)
        
        if plant_type:
            query = query.filter(PotPlant.plant_type == plant_type)
        
        if search:
            safe_search = search.replace('%', '\\%').replace('_', '\\_')
            query = query.filter(
                or_(
                    PotPlant.name.ilike(f'%{safe_search}%'),
                    PotPlant.description.ilike(f'%{safe_search}%')
                )
            )
        
        if min_price is not None:
            query = query.filter(PotPlant.base_price >= min_price)
        
        if max_price is not None:
            query = query.filter(PotPlant.base_price <= max_price)
        
        if min_rating is not None:
            query = query.filter(PotPlant.rating >= min_rating)
        
        if max_rating is not None:
            query = query.filter(PotPlant.rating <= max_rating)
        
        plants = query.all()

        return jsonify({
            'success': True,
            'data': [plant.to_dict() for plant in plants],
            'count': len(plants)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
    
# растение по ID
@bp.route('/<int:plant_id>', methods=['GET'], endpoint='plant_detail')
def get_plant(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        plant_data = plant.to_dict()
        
        if plant.category:
            plant_data['category'] = plant.category.to_dict()
        
        if plant.supplier:
            plant_data['supplier'] = plant.supplier.to_dict()
        
        return jsonify({
            'success': True,
            'data': plant_data
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# новое растение
@bp.route('/', methods=['POST'], endpoint='plant_create')
def create_plant():
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        required_fields = ['name', 'base_price', 'category_id']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        name = validate_string_input(data.get('name'), 100)
        if not name:
            return jsonify({
                'success': False,
                'error': 'Invalid plant name'
            }), 400
            
        base_price = safe_float(data.get('base_price'), min_val=0, max_val=1000000)
        if base_price is None:
            return jsonify({
                'success': False,
                'error': 'Invalid base price'
            }), 400
            
        category_id = safe_int(data.get('category_id'), min_val=1)
        if not category_id:
            return jsonify({
                'success': False,
                'error': 'Invalid category ID'
            }), 400
        
        # проверка категории
        category = Category.query.get(category_id)
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 400
        
        # проверка уникальности имени
        existing_plant = PotPlant.query.filter_by(name=name).first()
        if existing_plant:
            return jsonify({
                'success': False,
                'error': 'Plant with this name already exists'
            }), 400
        
        # валидация рейтинга
        rating = safe_float(data.get('rating'), min_val=0, max_val=5)
        
        plant = PotPlant(
            name=name,
            description=validate_string_input(data.get('description')),
            base_price=base_price,
            supplier_id=safe_int(data.get('supplier_id'), min_val=1),
            category_id=category_id,
            plant_type=validate_string_input(data.get('plant_type'), 20),
            recommended_pot_size=validate_string_input(data.get('recommended_pot_size'), 2),
            height_cm=safe_int(data.get('height_cm'), min_val=0, max_val=10000),
            care_instructions=validate_string_input(data.get('care_instructions')),
            light_requirements=validate_string_input(data.get('light_requirements'), 20),
            watering_frequency=validate_string_input(data.get('watering_frequency'), 50),
            rating=rating,
            in_stock=bool(data.get('in_stock', True)),
            image_url=validate_string_input(data.get('image_url'), 255)
        )
        
        db.session.add(plant)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': plant.to_dict(),
            'message': 'Plant created successfully'
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# обновление растения
@bp.route('/<int:plant_id>', methods=['PUT'], endpoint='plant_update')
def update_plant(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        if 'name' in data:
            name = validate_string_input(data.get('name'), 100)
            if not name:
                return jsonify({
                    'success': False,
                    'error': 'Invalid plant name'
                }), 400
            if name != plant.name:
                existing_plant = PotPlant.query.filter_by(name=name).first()
                if existing_plant and existing_plant.id != plant_id:
                    return jsonify({
                        'success': False,
                        'error': 'Plant with this name already exists'
                    }), 400
            plant.name = name
        
        updatable_fields = {
            'description': (validate_string_input, None),
            'base_price': (safe_float, {'min_val': 0, 'max_val': 1000000}),
            'supplier_id': (safe_int, {'min_val': 1}),
            'category_id': (safe_int, {'min_val': 1}),
            'plant_type': (validate_string_input, {'max_length': 20}),
            'recommended_pot_size': (validate_string_input, {'max_length': 2}),
            'height_cm': (safe_int, {'min_val': 0, 'max_val': 10000}),
            'care_instructions': (validate_string_input, None),
            'light_requirements': (validate_string_input, {'max_length': 20}),
            'watering_frequency': (validate_string_input, {'max_length': 50}),
            'rating': (safe_float, {'min_val': 0, 'max_val': 5}),
            'image_url': (validate_string_input, {'max_length': 255})
        }
        
        for field, (validator, kwargs) in updatable_fields.items():
            if field in data:
                if kwargs:
                    value = validator(data[field], **kwargs)
                else:
                    value = validator(data[field])
                if value is not None or field in ['description', 'care_instructions']:  # Разрешаем пустые описания
                    setattr(plant, field, value)
        
        if 'in_stock' in data:
            plant.in_stock = bool(data['in_stock'])
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': plant.to_dict(),
            'message': 'Plant updated successfully'
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# удаление
@bp.route('/<int:plant_id>', methods=['DELETE'], endpoint='plant_delete')
def delete_plant(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        # проверка на заказы
        if plant.order_items:
            return jsonify({
                'success': False,
                'error': 'Cannot delete plant with existing orders'
            }), 400
        
        db.session.delete(plant)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Plant deleted successfully'
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# загрузка картинки для растения
@bp.route('/<int:plant_id>/image', methods=['POST'], endpoint='plant_upload_image')
def upload_plant_image(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        if 'image' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No image file provided'
            }), 400
        
        file = request.files['image']
        
        if file.filename == '':
            return jsonify({
                'success': False,
                'error': 'No image selected'
            }), 400
        
        file.seek(0, os.SEEK_END)
        file_length = file.tell()
        file.seek(0)
        
        if file_length > MAX_FILE_SIZE:
            return jsonify({
                'success': False,
                'error': 'File size too large. Maximum size is 16MB'
            }), 400
        
        filename = save_uploaded_file(file)
        
        if not filename:
            return jsonify({
                'success': False,
                'error': 'Invalid file type. Allowed types: png, jpg, jpeg, gif, webp'
            }), 400
        
        plant.image_url = f"api/img/{filename}"
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Image uploaded successfully',
            'image_url': plant.image_url,
            'data': plant.to_dict()
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# удаление картинки растения
@bp.route('/<int:plant_id>/image', methods=['DELETE'], endpoint='plant_delete_image')
def delete_plant_image(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        if not plant.image_url:
            return jsonify({
                'success': False,
                'error': 'Plant does not have an image'
            }), 400
        
        try:
            img_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'img')
            filename = safe_filename(plant.image_url)
            
            if not filename:
                return jsonify({
                    'success': False,
                    'error': 'Invalid filename format'
                }), 400
                
            file_path = os.path.join(img_dir, filename)
            
            if os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"Error deleting file: {e}")
        
        plant.image_url = None
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Image deleted successfully',
            'data': plant.to_dict()
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# все категории
@bp.route('/categories', methods=['GET'], endpoint='categories_list')
def get_categories():
    try:
        categories = Category.query.all()
        
        return jsonify({
            'success': True,
            'data': [category.to_dict() for category in categories]
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# все фильтры 
@bp.route('/filters', methods=['GET'], endpoint='plants_filters')
def get_filters():
    try:
        plant_types = db.session.query(PotPlant.plant_type).distinct().all()
        plant_types = [pt[0] for pt in plant_types if pt[0]]
        
        categories = Category.query.all()

        price_range = db.session.query(
            db.func.min(PotPlant.base_price),
            db.func.max(PotPlant.base_price)
        ).first()
        
        rating_range = db.session.query(
            db.func.min(PotPlant.rating),
            db.func.max(PotPlant.rating)
        ).first()
        
        return jsonify({
            'success': True,
            'data': {
                'plant_types': plant_types,
                'categories': [cat.to_dict() for cat in categories],
                'price_range': {
                    'min': float(price_range[0] or 0),
                    'max': float(price_range[1] or 0)
                },
                'rating_range': {
                    'min': float(rating_range[0] or 0),
                    'max': float(rating_range[1] or 5)
                }
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
    
# обновить наличие 
@bp.route('/<int:plant_id>/stock', methods=['PATCH'], endpoint='plant_update_stock')
def update_stock(plant_id):
    try:
        plant_id = safe_int(plant_id, min_val=1)
        if not plant_id:
            return jsonify({
                'success': False,
                'error': 'Invalid plant ID'
            }), 400
            
        plant = PotPlant.query.get(plant_id)
        
        if not plant:
            return jsonify({
                'success': False,
                'error': 'Plant not found'
            }), 404
        
        data = request.get_json()
        
        if 'in_stock' not in data:
            return jsonify({
                'success': False,
                'error': 'in_stock field is required'
            }), 400
        
        plant.in_stock = bool(data['in_stock'])
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': plant.to_dict(),
            'message': f'Plant stock status updated to {plant.in_stock}'
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# растения с картинками
@bp.route('/with-images', methods=['GET'], endpoint='plants_with_images')
def get_plants_with_images():
    try:
        plants = PotPlant.query.filter(PotPlant.image_url.isnot(None)).all()
        
        return jsonify({
            'success': True,
            'data': [plant.to_dict() for plant in plants],
            'count': len(plants)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
    
# растения с высоким рейтингом
@bp.route('/top-rated', methods=['GET'], endpoint='plants_top_rated')
def get_top_rated_plants():
    try:
        min_rating = safe_float(request.args.get('min_rating', 4.0), min_val=0, max_val=5)
        limit = safe_int(request.args.get('limit', 10), min_val=1, max_val=100)
        
        plants = PotPlant.query.filter(
            PotPlant.rating >= min_rating,
            PotPlant.in_stock == True
        ).order_by(PotPlant.rating.desc()).limit(limit).all()
        
        return jsonify({
            'success': True,
            'data': [plant.to_dict() for plant in plants],
            'count': len(plants)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
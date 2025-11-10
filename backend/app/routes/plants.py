from flask import Blueprint, request, jsonify
from app import db
from app.models import PotPlant, Category, Supplier
from sqlalchemy import or_
import os
import uuid
from werkzeug.utils import secure_filename

bp = Blueprint('plants', __name__, url_prefix='/api/plants')

# Настройки для загрузки файлов
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16mb

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

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

# список растений с фильтрами
@bp.route('/', methods=['GET'], endpoint='plants_list')
def get_plants():
    try:
        category_id = request.args.get('category_id', type=int)
        in_stock = request.args.get('in_stock', type=lambda v: v.lower() == 'true')
        plant_type = request.args.get('plant_type')
        search = request.args.get('search')
        min_price = request.args.get('min_price', type=float)
        max_price = request.args.get('max_price', type=float)
        min_rating = request.args.get('min_rating', type=float)
        max_rating = request.args.get('max_rating', type=float)
    
        query = PotPlant.query

        if category_id:
            query = query.filter(PotPlant.category_id == category_id)
        
        if in_stock is not None:
            query = query.filter(PotPlant.in_stock == in_stock)
        
        if plant_type:
            query = query.filter(PotPlant.plant_type == plant_type)
        
        if search:
            query = query.filter(
                or_(
                    PotPlant.name.ilike(f'%{search}%'),
                    PotPlant.description.ilike(f'%{search}%')
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
            'error': str(e)
        }), 500
    
# растение по ID
@bp.route('/<int:plant_id>', methods=['GET'], endpoint='plant_detail')
def get_plant(plant_id):
    try:
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
            'error': str(e)
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
        
        # проверка категории
        category = Category.query.get(data['category_id'])
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 400
        
        # проверка уникальности имени
        existing_plant = PotPlant.query.filter_by(name=data['name']).first()
        if existing_plant:
            return jsonify({
                'success': False,
                'error': 'Plant with this name already exists'
            }), 400
        
        # валидация рейтинга
        rating = data.get('rating')
        if rating is not None:
            try:
                rating = float(rating)
                if rating < 0 or rating > 5:
                    return jsonify({
                        'success': False,
                        'error': 'Rating must be between 0 and 5'
                    }), 400
            except (ValueError, TypeError):
                return jsonify({
                    'success': False,
                    'error': 'Rating must be a valid number'
                }), 400
        
        plant = PotPlant(
            name=data['name'],
            description=data.get('description'),
            base_price=data['base_price'],
            supplier_id=data.get('supplier_id'),
            category_id=data['category_id'],
            plant_type=data.get('plant_type'),
            recommended_pot_size=data.get('recommended_pot_size'),
            height_cm=data.get('height_cm'),
            care_instructions=data.get('care_instructions'),
            light_requirements=data.get('light_requirements'),
            watering_frequency=data.get('watering_frequency'),
            rating=rating,
            in_stock=data.get('in_stock', True),
            image_url=data.get('image_url')
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
            'error': str(e)
        }), 500

# обновление растения
@bp.route('/<int:plant_id>', methods=['PUT'], endpoint='plant_update')
def update_plant(plant_id):
    try:
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
        
        updatable_fields = [
            'name', 'description', 'base_price', 'supplier_id', 'category_id',
            'plant_type', 'recommended_pot_size', 'height_cm', 'care_instructions',
            'light_requirements', 'watering_frequency', 'rating', 'in_stock', 'image_url'
        ]
        
        for field in updatable_fields:
            if field in data:
                if field == 'rating' and data[field] is not None:
                    try:
                        rating = float(data[field])
                        if rating < 0 or rating > 5:
                            return jsonify({
                                'success': False,
                                'error': 'Rating must be between 0 and 5'
                            }), 400
                    except (ValueError, TypeError):
                        return jsonify({
                            'success': False,
                            'error': 'Rating must be a valid number'
                        }), 400
                setattr(plant, field, data[field])
        
        # уникальность имени
        if 'name' in data and data['name'] != plant.name:
            existing_plant = PotPlant.query.filter_by(name=data['name']).first()
            if existing_plant and existing_plant.id != plant_id:
                return jsonify({
                    'success': False,
                    'error': 'Plant with this name already exists'
                }), 400
        
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
            'error': str(e)
        }), 500

# удаление
@bp.route('/<int:plant_id>', methods=['DELETE'], endpoint='plant_delete')
def delete_plant(plant_id):
    try:
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
            'error': str(e)
        }), 500

# загрузка картинки для растения
@bp.route('/<int:plant_id>/image', methods=['POST'], endpoint='plant_upload_image')
def upload_plant_image(plant_id):
    try:
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
            'error': str(e)
        }), 500

# удаление картинки растения
@bp.route('/<int:plant_id>/image', methods=['DELETE'], endpoint='plant_delete_image')
def delete_plant_image(plant_id):
    try:
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
            filename = plant.image_url.replace('img/', '')
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
            'error': str(e)
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
            'error': str(e)
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
            'error': str(e)
        }), 500
    
# обновить наличие 
@bp.route('/<int:plant_id>/stock', methods=['PATCH'], endpoint='plant_update_stock')
def update_stock(plant_id):
    try:
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
            'error': str(e)
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
            'error': str(e)
        }), 500
    
# растения с высоким рейтингом
@bp.route('/top-rated', methods=['GET'], endpoint='plants_top_rated')
def get_top_rated_plants():
    try:
        min_rating = request.args.get('min_rating', 4.0, type=float)
        limit = request.args.get('limit', 10, type=int)
        
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
            'error': str(e)
        }), 500
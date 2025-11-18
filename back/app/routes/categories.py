from flask import Blueprint, request, jsonify
from app import db
from app.models import Category, PotPlant
from sqlalchemy import or_
import re

bp = Blueprint('categories', __name__, url_prefix='/api/categories')

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
    """валидация строкового ввода"""
    if not text or not isinstance(text, str):
        return None
    cleaned = re.sub(r'[<>"\']', '', text.strip())
    return cleaned[:max_length] if cleaned else None

# все категории
@bp.route('/', methods=['GET'])
def get_categories():
    try:
        only_parents = request.args.get('only_parents', type=lambda v: v.lower() == 'true')
        
        query = Category.query
        
        if only_parents:
            query = query.filter(Category.parent_id == None)
        
        categories = query.all()
        
        # дерево категорий
        def build_category_tree(categories, parent_id=None):
            result = []
            for category in categories:
                if category.parent_id == parent_id:
                    category_dict = category.to_dict()
                    category_dict['subcategories'] = build_category_tree(categories, category.id)
                    result.append(category_dict)
            return result
        
        categories_tree = build_category_tree(categories)
        
        return jsonify({
            'success': True,
            'data': categories_tree,
            'count': len(categories)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# категория по ID
@bp.route('/<int:category_id>', methods=['GET'])
def get_category(category_id):
    try:
        category_id = safe_int(category_id, min_val=1)
        if not category_id:
            return jsonify({
                'success': False,
                'error': 'Invalid category ID'
            }), 400
            
        category = Category.query.get(category_id)
        
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 404
        
        category_data = category.to_dict()
        
        # информация о родительской категории
        if category.parent_id:
            parent_category = Category.query.get(category.parent_id)
            if parent_category:
                category_data['parent_category'] = parent_category.to_dict()
        
        # количество растений
        plants_count = PotPlant.query.filter_by(category_id=category_id).count()
        category_data['plants_count'] = plants_count
        
        # подкатегории
        subcategories = Category.query.filter_by(parent_id=category_id).all()
        category_data['subcategories'] = [subcat.to_dict() for subcat in subcategories]
        
        return jsonify({
            'success': True,
            'data': category_data
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# создать категорию
@bp.route('/', methods=['POST'])
def create_category():
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        # обязательные поля
        required_fields = ['name']
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
                'error': 'Invalid category name'
            }), 400
        
        description = validate_string_input(data.get('description'))
        parent_id = safe_int(data.get('parent_id'), min_val=1)
        
        # проверка уникальности имени
        existing_category = Category.query.filter_by(name=name).first()
        if existing_category:
            return jsonify({
                'success': False,
                'error': 'Category with this name already exists'
            }), 400
        
        # проверка на родителя
        if parent_id:
            parent_category = Category.query.get(parent_id)
            if not parent_category:
                return jsonify({
                    'success': False,
                    'error': 'Parent category not found'
                }), 400
        
        category = Category(
            name=name,
            description=description,
            parent_id=parent_id
        )
        
        db.session.add(category)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': category.to_dict(),
            'message': 'Category created successfully'
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# обновление категории
@bp.route('/<int:category_id>', methods=['PUT'])
def update_category(category_id):
    try:
        category_id = safe_int(category_id, min_val=1)
        if not category_id:
            return jsonify({
                'success': False,
                'error': 'Invalid category ID'
            }), 400
            
        category = Category.query.get(category_id)
        
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 404
        
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        # проверка на сам себе родитель
        if 'parent_id' in data and data['parent_id'] == category_id:
            return jsonify({
                'success': False,
                'error': 'Category cannot be parent of itself'
            }), 400
        
        # проверка на родительскую категорию
        parent_id = safe_int(data.get('parent_id'), min_val=1)
        if parent_id:
            parent_category = Category.query.get(parent_id)
            if not parent_category:
                return jsonify({
                    'success': False,
                    'error': 'Parent category not found'
                }), 400
        
        # обновление поля
        if 'name' in data:
            name = validate_string_input(data.get('name'), 100)
            if not name:
                return jsonify({
                    'success': False,
                    'error': 'Invalid category name'
                }), 400
            # проверка на уникальность имени
            if name != category.name:
                existing_category = Category.query.filter_by(name=name).first()
                if existing_category and existing_category.id != category_id:
                    return jsonify({
                        'success': False,
                        'error': 'Category with this name already exists'
                    }), 400
            category.name = name
        
        if 'description' in data:
            category.description = validate_string_input(data.get('description'))
        
        if 'parent_id' in data:
            category.parent_id = parent_id
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'data': category.to_dict(),
            'message': 'Category updated successfully'
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# удалить категорию
@bp.route('/<int:category_id>', methods=['DELETE'])
def delete_category(category_id):
    try:
        category_id = safe_int(category_id, min_val=1)
        if not category_id:
            return jsonify({
                'success': False,
                'error': 'Invalid category ID'
            }), 400
            
        category = Category.query.get(category_id)
        
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 404
        
        # проверка на товары в категории
        plants_count = PotPlant.query.filter_by(category_id=category_id).count()
        if plants_count > 0:
            return jsonify({
                'success': False,
                'error': f'Cannot delete category with {plants_count} plants. Move plants to another category first.'
            }), 400
        
        # проверка на подкатегории
        subcategories_count = Category.query.filter_by(parent_id=category_id).count()
        if subcategories_count > 0:
            return jsonify({
                'success': False,
                'error': f'Cannot delete category with {subcategories_count} subcategories. Delete or move subcategories first.'
            }), 400
        
        db.session.delete(category)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Category deleted successfully'
        })
    
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# растения в категориям
@bp.route('/<int:category_id>/plants', methods=['GET'])
def get_category_plants(category_id):
    try:
        category_id = safe_int(category_id, min_val=1)
        if not category_id:
            return jsonify({
                'success': False,
                'error': 'Invalid category ID'
            }), 400
            
        category = Category.query.get(category_id)
        
        if not category:
            return jsonify({
                'success': False,
                'error': 'Category not found'
            }), 404
        
        # параметры фильтров 
        in_stock = request.args.get('in_stock', type=lambda v: v.lower() == 'true')
        plant_type = validate_string_input(request.args.get('plant_type'), 20)
        
        query = PotPlant.query.filter_by(category_id=category_id)
        
        if in_stock is not None:
            query = query.filter(PotPlant.in_stock == in_stock)
        
        if plant_type:
            query = query.filter(PotPlant.plant_type == plant_type)
        
        plants = query.all()
        
        return jsonify({
            'success': True,
            'data': {
                'category': category.to_dict(),
                'plants': [plant.to_dict() for plant in plants],
                'count': len(plants)
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

# статистика по категориям
@bp.route('/stats', methods=['GET'])
def get_categories_stats():
    try:
        stats = db.session.query(
            Category.id,
            Category.name,
            db.func.count(PotPlant.id).label('plants_count')
        ).outerjoin(PotPlant, Category.id == PotPlant.category_id)\
         .group_by(Category.id)\
         .all()
        
        result = []
        for stat in stats:
            result.append({
                'category_id': stat.id,
                'category_name': stat.name,
                'plants_count': stat.plants_count
            })
        
        return jsonify({
            'success': True,
            'data': result
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
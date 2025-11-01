from flask import Blueprint, request, jsonify
from app import db
from app.models import PotPlant, Category, Supplier
from sqlalchemy import or_

bp = Blueprint('plants', __name__, url_prefix='/api/plants')

# список растений с фильтрами
@bp.route('/', methods =['GET'])
def get_plants():
    try:
        category_id = request.args.get('category_id', type=int)
        in_stock = request.args.get('in_stock', type=lambda v: v.lower() == 'true')
        plant_type = request.args.get('plant_type')
        search = request.args.get('search')
        min_price = request.args.get('min_price', type=float)
        max_price = request.args.get('max_price', type=float)
    
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
@bp.route('/<int:plant_id>', methods=['GET'])
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
@bp.route('/', methods=['POST'])
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
        
        # проверка уникальность
        existing_plant = PotPlant.query.filter_by(name=data['name']).first()
        if existing_plant:
            return jsonify({
                'success': False,
                'error': 'Plant with this name already exists'
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
            in_stock=data.get('in_stock', True)
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

# обновение имени
@bp.route('/<int:plant_id>', methods=['PUT'])
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
            'light_requirements', 'watering_frequency', 'in_stock'
        ]
        
        for field in updatable_fields:
            if field in data:
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
@bp.route('/<int:plant_id>', methods=['DELETE'])
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
    
# все категории
@bp.route('/categories', methods=['GET'])
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
@bp.route('/filters', methods=['GET'])
def get_filters():
    try:
        plant_types = db.session.query(PotPlant.plant_type).distinct().all()
        plant_types = [pt[0] for pt in plant_types if pt[0]]
        
        categories = Category.query.all()

        price_range = db.session.query(
            db.func.min(PotPlant.base_price),
            db.func.max(PotPlant.base_price)
        ).first()
        
        return jsonify({
            'success': True,
            'data': {
                'plant_types': plant_types,
                'categories': [cat.to_dict() for cat in categories],
                'price_range': {
                    'min': float(price_range[0] or 0),
                    'max': float(price_range[1] or 0)
                }
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
    
# обновить наличие 
@bp.route('/<int:plant_id>/stock', methods=['PATCH'])
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
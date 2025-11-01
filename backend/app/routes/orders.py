from flask import Blueprint, jsonify

bp = Blueprint('orders', __name__, url_prefix='/api/orders')
# временная заглушка
@bp.route('/', methods=['GET'])
def get_orders():
    return jsonify({'success': True, 'message': 'Orders endpoint'})
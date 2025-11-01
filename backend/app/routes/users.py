from flask import Blueprint, jsonify

bp = Blueprint('users', __name__, url_prefix='/api/users')
# временная заглушка
@bp.route('/', methods=['GET'])
def get_users():
    return jsonify({'success': True, 'message': 'Users endpoint'})
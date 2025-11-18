from flask import Blueprint, jsonify

bp = Blueprint('employees', __name__, url_prefix='/api/employees')
# временная заглушка
@bp.route('/', methods=['GET'])
def get_employees():
    return jsonify({'success': True, 'message': 'Employees endpoint'})
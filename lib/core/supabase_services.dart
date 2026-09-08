import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseServices {
	static SupabaseClient get _client => Supabase.instance.client;

	static Future<void> signIn({
		required String email,
		required String password,
	}) async {
		await _client.auth.signInWithPassword(
			email: email,
			password: password,
		);
	}

	static Future<void> signOut() async {
		await _client.auth.signOut();
	}

	static Future<void> signUpPaciente({
		required String email,
		required String password,
		required String fullName,
		required DateTime birthDate,
	}) async {
		final authResponse = await _client.auth.signUp(
			email: email,
			password: password,
		);

		final user = authResponse.user;
		if (user == null) {
			throw Exception('No se pudo crear el usuario en auth.users');
		}

		final session = authResponse.session ?? _client.auth.currentSession;
		if (session == null) {
			throw Exception(
				'Registro creado en Auth, pero no hay sesion activa. '
				'Revisa si la confirmacion por correo esta habilitada en Supabase.',
			);
		}

		final parsedName = _parseName(fullName);

		await _client.from('perfiles').upsert({
			'id_usuario': user.id,
			'nombre': parsedName.nombre,
			'apellido_paterno': parsedName.apellidoPaterno,
			'apellido_materno': parsedName.apellidoMaterno,
		});

		await _client.from('pacientes').upsert({
			'id_usuario': user.id,
			'nacimiento': _dateOnlyIso(birthDate),
		});
	}

	static String _dateOnlyIso(DateTime date) {
		final year = date.year.toString().padLeft(4, '0');
		final month = date.month.toString().padLeft(2, '0');
		final day = date.day.toString().padLeft(2, '0');
		return '$year-$month-$day';
	}

	static _ParsedName _parseName(String fullName) {
		final tokens = fullName
				.trim()
				.split(RegExp(r'\s+'))
				.where((token) => token.isNotEmpty)
				.toList();

		if (tokens.isEmpty) {
			return const _ParsedName(nombre: 'Usuario', apellidoPaterno: 'Paciente');
		}

		if (tokens.length == 1) {
			return _ParsedName(nombre: tokens.first, apellidoPaterno: 'Paciente');
		}

		if (tokens.length == 2) {
			return _ParsedName(nombre: tokens[0], apellidoPaterno: tokens[1]);
		}

		return _ParsedName(
			nombre: tokens.first,
			apellidoPaterno: tokens[1],
			apellidoMaterno: tokens.sublist(2).join(' '),
		);
	}
}

class _ParsedName {
	final String nombre;
	final String apellidoPaterno;
	final String? apellidoMaterno;

	const _ParsedName({
		required this.nombre,
		required this.apellidoPaterno,
		this.apellidoMaterno,
	});
}

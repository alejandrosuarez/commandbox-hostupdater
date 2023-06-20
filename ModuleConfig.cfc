component accessors=true {

	public any function configure() {
		return;
	}

	// Legacy behavior for CommandBox 5.x and prior
	public void function preServerStart( interceptData ) {

		if( isModernCommandBox() ) {
			return;
		}

		var hostname = 	arguments.interceptData.serverProps.host 				  ?: 			// host provided on the command line?
						arguments.interceptData.serverDetails.serverJSON.web.host ?:			// host provided in server.json?
						wirebox.getInstance( 'ServerService' ).getDefaultServerJSON().web.host; // if nothing was provided, use default (127.0.0.1)

		var aliases  =  arguments.interceptData.serverProps.hostAlias					?:		// hostAlias provided on the command line?
						arguments.interceptData.serverDetails.serverJSON.web.hostAlias 	?:		// hostAlias provided 'web' section of server.json?
						arguments.interceptData.serverDetails.serverJSON.hostAlias 		?:		// hostAlias provided in server.json?
						[];																		// if nothing was provided, use default (empty array)

		var systemSettings = wirebox.getInstance( 'SystemSettings' );

		if( !isArray( aliases ))
			aliases = aliases.listToArray();

		arraySort( aliases, 'text' );

		if( !isEmpty( aliases ) )
			arguments.interceptData.serverDetails.serverJSON["web"]["hostAlias"] = duplicate( aliases );

		var ary = duplicate( aliases);
		ary = ary.prepend( hostname )
					.reduce( ( arr, alias ) => {
					if( alias.reFindNoCase( '[$a-z]') && !arr.find( alias ) ){
						// [CS] [2018-03-15] if the alias is a system var, use the evaluated value
						if( left( alias, 1 ) == '$' )
							alias = systemSettings.expandSystemSettings( alias );

						arr.append( alias );

					}

					return arr;
					}, [] )
					.filter( ( host ) => host != 'localhost' );

		wirebox.getInstance( 'hostupdaterService@commandbox-hostupdater' ).checkIP( arguments.interceptData.serverDetails.serverInfo.id, ary );

		structDelete( arguments.interceptData.serverProps, "hostAlias", false );
		structDelete( arguments.interceptData.serverDetails.serverJSON, 'hostAlias', false );

		return;
	}

	// Modern CommandBox behavior starting in 6.0 which takes bindings into account
	public void function onBindingsBuild( interceptData ) {
		// Provide a way to turn this off per-server
		var enabled = arguments.interceptData.serverDetails.serverJSON.hostUpdaterEnable ?: true;

		if( !enabled ) {
			return;
		}

		var hostname = 	arguments.interceptData.serverInfo.host;

		var aliases  =  arguments.interceptData.serverProps.hostAlias					?:		// hostAlias provided on the command line?
						arguments.interceptData.serverDetails.serverJSON.web.hostAlias 	?:		// hostAlias provided 'web' section of server.json?
						arguments.interceptData.serverDetails.serverJSON.hostAlias 		?:		// hostAlias provided in server.json?
						[];																		// if nothing was provided, use default (empty array)

		aliases = duplicate( aliases );
		if( !isArray( aliases ))
			aliases = aliases.listToArray();

		// TODO: handle bindings on a specific local IP address that isn't localhost.
		// The host file entries will only work for bindings to localhost OR all IPs, and may affect the order of binding resolution.
		interceptData.bindings.each( (binding)=>{
			// ignore wildcard, regex, and default bindings.
			aliases.append( binding.hosts.filter( (a)=>!a.findNoCase('*') && !a.startsWith('~') ), true );
		} );

		arraySort( aliases, 'text' );

		aliases = aliases.prepend( hostname )
			// CommandBox now uses `hostAlias` for multi-site hostname bindings
			// so ignore any IP addresses, wildcards or regular expression matches, only taking fully qualified host names.
			.filter( (alias)=>!alias.startsWith('~') && !(alias contains '*') && alias != 'localhost' && !reFind( '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$', alias ) )
			.reduce( ( arr, alias ) => {
				if( !arr.findNoCase( alias ) ){
					arr.append( alias );
				}
				return arr;
			}, [] );

		wirebox.getInstance( 'hostupdaterService@commandbox-hostupdater' ).checkIP( arguments.interceptData.serverDetails.serverInfo.id, aliases );

		return;
	}

	public void function postServerForget( interceptData ) {

		wirebox.getInstance( 'hostupdaterService@commandbox-hostupdater' ).forgetServer( arguments.interceptData.serverInfo.id );

		return;
	}

	function isModernCommandBox() {
		var CommandBoxVersion = shell.getVersion();
		if( val( listFirst( CommandBoxVersion, '.' ) ) >= 6 || CommandBoxVersion contains '@build.version@' ) {
			return true;
		}
		return false;
	}
}

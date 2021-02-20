package FHEM::AirUnit;

use GPUtils         qw(:all);
use strict;
use warnings;

#use SetExtensions;

require DevIo;

BEGIN {
    GP_Import( qw(
		AttrVal
		CommandAttr
		readingsSingleUpdate
		readingsBeginUpdate
		readingsBulkUpdate
		readingsEndUpdate
		readingFnAttributes
		Log3
		gettimeofday
		InternalVal
		InternalTimer
		RemoveInternalTimer
    ));
};

GP_Export(
    qw(
      Initialize
      )
);

my $Version = '0.0.4.0 - Feb 2021';

####################### GET Paramter ################################################  
# Das sind die Zahlen die gesendet werden müssen, damit man die Informationen erhält.
#####################################################################################

my @OUTDOOR_TEMPERATURE = (0x01, 0x04, 0x03, 0x34);		#### REGISTER_1_READ, OUTDOOR_TEMPERATURE
my @ROOM_TEMPERATURE = (0x01, 0x04, 0x03, 0x00);		#### REGISTER_1_READ, ROOM_TEMPERATURE
my @SUPPLY_TEMPERATURE = (0x01, 0x04, 0x14, 0x73);		#### REGISTER_1_READ, SUPPLY_TEMPERATURE / ZULUFT
my @EXTRACT_TEMPERATURE = (0x01, 0x04, 0x14, 0x74);		#### REGISTER_1_READ, EXTRACT_TEMPERATURE / ABLUFT
my @EXHAUST_TEMPERATURE = (0x01, 0x04, 0x14, 0x75);		#### REGISTER_1_READ, EXHAUST_TEMPERATURE

my @HUMIDITY = (0x01, 0x04, 0x14, 0x70);  				#### REGISTER_1_READ, HUMIDITY
my @FAN_SPEED_SUPPLY = (0x04, 0x04, 0x14, 0x28);		#### REGISTER_1_READ, FAN_SPEED_SUPPLY
my @FAN_SPPED_EXTRACT = (0x04, 0x04, 0x14, 0x29);		#### REGISTER_1_READ, FAN_SPPED_EXTRACT
my @AIR_INPUT = (0x01, 0x04, 0x14, 0x40);				#### REGISTER_1_READ, AIR_INPUT
my @AIR_OUTPUT = (0x01, 0x04, 0x14, 0x41);				#### REGISTER_1_READ, AIR_OUTPUT
my @BATTERY_LIFE = (0x01, 0x04, 0x03, 0x0f);			#### REGISTER_1_READ, BATTERY_LIFE
my @FILTER_LIFE = (0x01, 0x04, 0x14, 0x6a);				#### REGISTER_1_READ, FILTER_LIFE

my @BOOST = (0x01, 0x04, 0x15, 0x30);					#### REGISTER_1_READ, BOOST ON/OFF
my @BOOST_AUTOMATIC = (0x01, 0x04, 0x17, 0x02);			#### REGISTER_1_READ, BOOST_AUTOMATIC ON/OFF
my @BYPASS = (0x01, 0x04, 0x14, 0x60);					#### REGISTER_1_READ, BYPASS
my @BYPASS_AUTOMATIC = (0x01, 0x04, 0x17, 0x06);		#### REGISTER_1_READ, BYPASS_AUTOMATIC ON/OFF
my @NIGHTCOOLING = (0x01, 0x04, 0x15, 0x71);			#### REGISTER_1_READ, NIGHTCOOLING ON/OFF
my @FIREPLACE = (0x01, 0x04, 0x17, 0x07);				#### REGISTER_1_READ, FIREPLACE ON/OFF
#my @COOKERHOOD = (0x01, 0x04, 0x15, 0x34);				#### REGISTER_1_READ, COOKERHOOD ON/OFF

my @MODE = (0x01, 0x04, 0x14, 0x12);					#### REGISTER_1_READ, MODE
my @FAN_STEP = (0x01, 0x04, 0x15, 0x61);				#### REGISTER_1_READ, FANSPEED / FANSTUFE in MANUELL - MODE

my @FANSPEED_IN_RPM = (0x04, 0x04, 0x14, 0x50);			#### REGISTER_1_READ, FANSPEED_IN_RPM
my @FANSPEED_OUT_RPM = (0x04, 0x04, 0x14, 0x51);		#### REGISTER_1_READ, FANSPEED_OUT_RPM

my @MODEL = (0x01, 0x04, 0x15, 0xe5);					#### REGISTER_1_READ, MODEL
my @MODEL_SN = (0x04, 0x04, 0x00, 0x25);				#### REGISTER_4_READ, MODEL SERIALNUMBER

####################### SET Paramter ##################################################################
# Das sind die Zahlen die gesendet werden müssen + eine 5. (die Option), damit man etwas bewirken kann.
#######################################################################################################

my @W_BOOST = (0x01, 0x06, 0x15, 0x30);						#### REGISTER_1_WRITE, BOOST ON/OFF
my @W_BYPASS = (0x01, 0x06, 0x14, 0x63);					#### REGISTER_1_WRITE, BYPASS ON/OFF
my @W_NIGHTCOOLING = (0x01, 0x06, 0x15, 0x71);				#### REGISTER_1_WRITE, NIGHTCOOLING ON/OFF
my @W_DISABLE_BOOST_AUTOMATIC = (0x01, 0x06, 0x17, 0x02);	#### REGISTER_1_WRITE, BOOST_AUTOMATIC ON/OFF
my @W_DISABLE_BYPASS_AUTOMATIC = (0x01, 0x06, 0x17, 0x06);	#### REGISTER_1_WRITE, BYPASS_AUTOMATIC ON/OFF
my @W_MODE = (0x01, 0x06, 0x14, 0x12);						#### REGISTER_1_WRITE, MODE
my @W_FAN_STEP = (0x01, 0x06, 0x15, 0x61);					#### REGISTER_1_WRITE, FAN_STEP
my @W_FIREPLACE = (0x01, 0x06, 0x17, 0x07);					#### REGISTER_1_WRITE, FIREPLACE ON/OFF
#my @W_COOKERHOOD = (0x01, 0x06, 0x15, 0x34);				#### REGISTER_1_WRITE, COOKERHOOD ON/OFF

########################################

sub Initialize()
{
  my ($hash) = @_;

  $hash->{DefFn}    = \&Define;			# definiert das Gerät
  $hash->{UndefFn}  = \&Undefine;		# legt fest, was alles mein löschen gemacht wird
  $hash->{GetFn}    = \&Get;			# nicht wirklich benötigt, eher ein TEST, viell. fällt mir noch was ein
  $hash->{SetFn}    = \&Set;			# dient zum setzen der SET Paramter
  $hash->{ReadFn}   = \&Read;			# wird von DevIO beim Nachrichteneingang gerufen
  $hash->{ReadyFn}  = \&Ready;			# wird von DevIO bei Kommunikationsproblemen gerufen
  $hash->{AttrFn}   = \&Attr;			# nur kopiert und angepasst
  $hash->{AttrList} = "disable:0,1 ".
					"allowSetParameter:0,1 ".
					$readingFnAttributes;
}

########################################

sub Define(){
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);

	return "Usage: define <name> AirUnit <ip-address:port> [poll-interval]" 
	if(@a <3 || @a >4);

	my $name = $a[0];
	my $host = $a[2];
	my $port = 30046;

	my $interval = 5*60;
	$interval = $a[3] if(int(@a) == 4);
	$interval = 30 if( $interval < 30 );

	$hash->{NAME} = $name;
	$hash->{ModuleVersion} = $Version;

	$hash->{STATE} = "Initializing";
	if ( $host =~ /(.*):(.*)/ ) {
		$host = $1;
		$port = $2;
	}
	$hash->{INTERVAL} = $interval;
	$hash->{NOTIFYDEV} = "global";
	$hash->{DeviceName} = join(':', $host, $port);

  	$hash->{helper}{commandQueue} = [];

	::DevIo_CloseDev($hash) if ( ::DevIo_IsOpen($hash) );
	::DevIo_OpenDev( $hash, 0, undef, \&Callback );

	return undef;	
}

########################################

sub Undefine() {
	
	my ($hash, $arg) = @_;
	RemoveInternalTimer($hash);		# Timer wird gelöscht
	::DevIo_CloseDev($hash);
	return undef;
}

########################################
# called repeatedly if device disappeared

sub Ready()
{
  my ($hash) = @_;
  
  # try to reopen the connection in case the connection is lost
  return ::DevIo_OpenDev($hash, 1, undef, \&Callback); 
}

########################################
# called when data was received

sub Read()
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my %commands;

  # read the available data
  my $buf = ::DevIo_SimpleRead($hash);
  
  # stop processing if no data is available (device disconnected)
  return if(!defined($buf));
  
  Log3($name, 4, "AirUnit ($name) - received: ".unpack('H*', $buf));

  #
  # do something with $buf, e.g. generate readings, send answers via DevIo_SimpleWrite(), ...
  #

  # map commands to actions
  $commands{getCommandKey(@OUTDOOR_TEMPERATURE)} = sub {
	readingsSingleUpdate( $hash, "Aussenluft_Temperatur", getTemperatur($hash, $buf), 1);
  };
  $commands{getCommandKey(@ROOM_TEMPERATURE)} = sub {
	readingsSingleUpdate( $hash, "Raumluft_Temperatur_AirDail", getTemperatur($hash, $buf), 1);
  };
  $commands{getCommandKey(@SUPPLY_TEMPERATURE)} = sub {
	readingsSingleUpdate( $hash, "Zuluft_Temperatur", getTemperatur($hash, $buf), 1);
  };
  $commands{getCommandKey(@EXTRACT_TEMPERATURE)} = sub {
	readingsSingleUpdate( $hash, "Abluft_Temperatur", getTemperatur($hash, $buf), 1);
  };
  $commands{getCommandKey(@EXHAUST_TEMPERATURE)} = sub {
	readingsSingleUpdate( $hash, "Fortluft_Temperatur", getTemperatur($hash, $buf), 1);
  };
  $commands{getCommandKey(@HUMIDITY)} = sub {
	readingsSingleUpdate( $hash, "Luftfeuchtigkeit", getHumidity($hash, $buf), 1);
  };
  $commands{getCommandKey(@AIR_INPUT)} = sub {
	readingsSingleUpdate( $hash, "Zuluft_Grundstufe_Einstellung", getAirInputOutput($hash, $buf), 1);
  };
  $commands{getCommandKey(@AIR_OUTPUT)} = sub {
	readingsSingleUpdate( $hash, "Abluft_Grundstufe_Einstellung", getAirInputOutput($hash, $buf), 1);
  };
  $commands{getCommandKey(@FAN_SPEED_SUPPLY)} = sub {
	readingsSingleUpdate( $hash, "Zuluft_Stufe", getAirInputOutput($hash, $buf), 1);
  };
  $commands{getCommandKey(@FAN_SPPED_EXTRACT)} = sub {
	readingsSingleUpdate( $hash, "Abluft_Stufe", getAirInputOutput($hash, $buf), 1);
  };
  $commands{getCommandKey(@FILTER_LIFE)} = sub {
	readingsSingleUpdate( $hash, "verbl.Filterlebensdauer", getFilterLifeTime($hash, $buf), 1);
  };
  $commands{getCommandKey(@BATTERY_LIFE)} = sub {
	readingsSingleUpdate( $hash, "verbl.Batterielebensdauer_AirDial", getBatteryLifeTime($hash, $buf), 1);
  };
  $commands{getCommandKey(@BOOST)} = sub {
	readingsSingleUpdate( $hash, "Stosslueftung", getONOFF($hash, $buf), 1);
  };
   $commands{getCommandKey(@BYPASS)} = sub {
	readingsSingleUpdate( $hash, "Bypass", getONOFF($hash, $buf), 1);
  };
   $commands{getCommandKey(@NIGHTCOOLING)} = sub {
	readingsSingleUpdate( $hash, "Stosslueftung", getONOFF($hash, $buf), 1);
  };
   $commands{getCommandKey(@FIREPLACE)} = sub {
	readingsSingleUpdate( $hash, "Bypass", getONOFF($hash, $buf), 1);
  };
   $commands{getCommandKey(@BOOST_AUTOMATIC)} = sub {
	readingsSingleUpdate( $hash, "automatische_Stosslueftung", getOFFON($hash, $buf), 1);
  }; 
   $commands{getCommandKey(@BYPASS_AUTOMATIC)} = sub {
	readingsSingleUpdate( $hash, "automatischer_Bypass", getOFFON($hash, $buf), 1);
  };
   $commands{getCommandKey(@FANSPEED_IN_RPM)} = sub {
	readingsSingleUpdate( $hash, "Zuluft_Luefterdrehzahl", getFanSpeedInRPM($hash, $buf), 1);
  };
   $commands{getCommandKey(@FANSPEED_OUT_RPM)} = sub {
	readingsSingleUpdate( $hash, "Abluft_Luefterdrehzahl", getFanSpeedInRPM($hash, $buf), 1);
  };
   $commands{getCommandKey(@MODEL)} = sub {
	readingsSingleUpdate( $hash, "Model", getModel($hash, $buf), 1);
  };
   $commands{getCommandKey(@MODEL_SN)} = sub {
	readingsSingleUpdate( $hash, "Seriennummer", getModelSN($hash, $buf), 1);
  };
   $commands{getCommandKey(@MODE)} = sub {
	readingsSingleUpdate( $hash, "Modus", getMode($hash, $buf), 1);
  };
   $commands{getCommandKey(@FAN_STEP)} = sub {
	readingsSingleUpdate( $hash, "Luefterstufe", getFanSpeed($hash, $buf), 1);
  };  
  my $lastCmd = InternalVal($name, 'LastCommand', '');
  
  if (defined($commands{$lastCmd})) {
	$commands{$lastCmd}->();
  } else {
  	Log3($name, 4, "AirUnit ($name) - handling of command not defined: $lastCmd");
  }

  sendNextRequest($hash);
}

##########################################################################
# will be executed if connection establishment fails (see DevIo_OpenDev())
##########################################################################

sub Callback()
{
    my ($hash, $error) = @_;
    my $name = $hash->{NAME};

	# create a log emtry with the error message
	Log3($name, 5, "AirUnit ($name) - error while connecting: $error") if($error);

	GetUpdate($hash);

    return undef;
}

########################################

sub Get() {
	
  my ($hash, $name, $cmd, @val ) = @_;
  
  if($cmd eq 'update') {
	  DoUpdate($hash) if (::DevIo_IsOpen($hash));			
   }
   elsif($cmd eq 'nothing') {
      # Log3 $name, 3, "get $name $cmd";
      if (int @val !=1000) {
         my $msg = "Wrong number of parameter (".int @val.")in get $name $cmd";
         Log3($name, 3, $msg);
         return $msg;
      }
   }
   elsif( $cmd eq 'get_Overview') {
	  # Log3 $name, 3, "get $name $cmd";
      if (int @val !=4000 ) {
         my $msg = "Wrong number of parameter (".int @val.")in get $name $cmd";
         Log3($name, 3, $msg);
         return $msg;
      }
   }

   my $list = " update:noArg"
			. " nothing"
			. " get_Overview:noArg";
       
   return "Unknown argument $cmd, choose one of $list";
}

########################################

sub Set() {

	my ($hash, $name, $cmd, $val) = @_;
	my @w_settings;
  
	if($cmd eq 'Modus') {
      Log3($name, 3, "set $name $cmd $val");
		if($val eq "Bedarfsmodus"){
			@w_settings = (@W_MODE, 0x00);
		}elsif($val eq "Programm"){
			@w_settings = (@W_MODE, 0x01);
		}elsif($val eq "Manuell"){
			@w_settings = (@W_MODE, 0x02);
		}elsif($val eq "Aus"){
			@w_settings = (@W_MODE, 0x03);
		}else {
			die "Fehlerhafter Paramter \n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Luefterstufe') {
		Log3($name, 3, "set $name $cmd $val");
#		my $myMode = ReadingsVal($name, "Modus" , "");
#		if (($val <= 10 || $val >= 1) and $myMode eq "Manuell"){
		if ($val <= 10 || $val >= 1){
			@w_settings = (@W_FAN_STEP, $val);
			sendRequest($hash, @w_settings);
		}else{	
			return "Lueftung ist nicht im manuellen Modus.";
		}
		return undef;
	}
    elsif ($cmd eq 'Boost'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_BOOST, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_BOOST, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
		}
	elsif ($cmd eq 'Bypass'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_BYPASS, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_BYPASS, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Nachtkuehlung'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_NIGHTCOOLING, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_NIGHTCOOLING, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Feuerstaette'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_FIREPLACE, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_FIREPLACE, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	# elsif ($cmd eq 'Dunstabzugshaube'){
		# Log3($name, 3, "set $name $cmd $val");
		# if($val eq "on"){
			# @w_settings = (@W_COOKERHOOD, 0x01);
		# }elsif($val eq "off"){
			# @w_settings = (@W_COOKERHOOD, 0x00);
		# }else {
			# die "Fehlerhafter Paramter $val für Setting $cmd\n";
		# }
		# #setONOFF($hash, @w_settings);
		# sendRequest($hash, @w_settings);
		# return undef;
	# }
	elsif ($cmd eq 'automatischerBoost'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_DISABLE_BOOST_AUTOMATIC, 0x00);
		}elsif($val eq "off"){
			@w_settings = (@W_DISABLE_BOOST_AUTOMATIC, 0x01);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'automatischerBypass'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_DISABLE_BYPASS_AUTOMATIC, 0x00);
		}elsif($val eq "off"){
			@w_settings = (@W_DISABLE_BYPASS_AUTOMATIC, 0x01);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif($cmd eq 'Intervall' && int(@_)==4 ) {
      Log3($name, 3, "set $name $cmd $val");
      $val = 30 if( $val < 30 );
      $hash->{INTERVAL} = $val;
      return "Intervall wurde auf $val Sekunden gesetzt.";
   }
	
	my $list = " Modus:Bedarfsmodus,Programm,Manuell,Aus "
		." Luefterstufe:slider,1,1,10 "
		." Boost:on,off "
		." Bypass:on,off "
		." Nachtkuehlung:on,off "
		." Feuerstaette:on,off "
#		." Dunstabzugshaube:on,off "
		." automatischerBoost:on,off "
		." automatischerBypass:on,off "
		." Intervall";
          
	return "Unknown argument $cmd, choose one of $list";
}

######################################## 	
# hier ist noch die Frage was man an Attributen setzen könnte... zB on-for-timer für die erweiterten Settings wäre gut
# viell kann man dann sagen on-for-timer BOOST Modus (wobei der Boost Modus in der Anlage eine über einen externen Controller setztbaren Timer hat)

sub Attr() {
	
	   my ($cmd,$name,$aName,$aVal) = @_;
	   # $cmd can be "del" or "set"
	   # $name is device name
	   # aName and aVal are Attribute name and value
	   if ($cmd eq "set") {
		  if ($aName eq "allowSetParameter") {
			 eval { qr/$aVal/ };
			 if ($@) {
				Log3($name, 3, "Invalid allowSetParameter in attr $name $aName $aVal: $@");
				return "Invalid allowSetParameter $aVal";
			 }
		  }
	   }
	   
	   return undef;
}

########################################

sub GetUpdate() {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer($hash);
	InternalTimer(gettimeofday()+$hash->{INTERVAL}, \&GetUpdate, $hash, 0);
	return undef if( AttrVal($name, "disable", 0 ) == 1 );

	DoUpdate($hash) if (::DevIo_IsOpen($hash));
}

########################################

sub DoUpdate(){

	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $queueRef = $hash->{helper}{commandQueue};

	my $orgQueueCount = @$queueRef;

	# Update readings
 
	# get_Temperature_Value

	push(@$queueRef, \@OUTDOOR_TEMPERATURE);
	push(@$queueRef, \@ROOM_TEMPERATURE);
	push(@$queueRef, \@SUPPLY_TEMPERATURE);
	push(@$queueRef, \@EXTRACT_TEMPERATURE);
	push(@$queueRef, \@EXHAUST_TEMPERATURE);

	# get_Value_in_Percent

	push(@$queueRef, \@HUMIDITY);
	push(@$queueRef, \@AIR_INPUT);
	push(@$queueRef, \@AIR_OUTPUT);
	push(@$queueRef, \@FAN_SPEED_SUPPLY);
	push(@$queueRef, \@FAN_SPPED_EXTRACT);

	# get_Lifetimes_in_Percent

	push(@$queueRef, \@FILTER_LIFE);
	push(@$queueRef, \@BATTERY_LIFE);

	# get_ON_or_OFF_Value

	push(@$queueRef, \@BOOST);
	push(@$queueRef, \@BYPASS);
	push(@$queueRef, \@NIGHTCOOLING);
	push(@$queueRef, \@FIREPLACE);
	push(@$queueRef, \@BOOST_AUTOMATIC);
	push(@$queueRef, \@BYPASS_AUTOMATIC);

	# get_FanSpeed_in_RPM

	push(@$queueRef, \@FANSPEED_IN_RPM);
	push(@$queueRef, \@FANSPEED_OUT_RPM);

	#get_String

	push(@$queueRef, \@MODEL);
	push(@$queueRef, \@MODEL_SN);

	# get_Value

	push(@$queueRef, \@MODE);
	push(@$queueRef, \@MODEL_SN);
	push(@$queueRef, \@FAN_STEP);

	sendNextRequest($hash) if ($orgQueueCount == 0);
}

########################################
############# SET Methoden #############
########################################

sub setFanSpeed() {
	# write Lüftergeschwindigskeitsstufe von 1-10
	my ($hash,@w_settings) = @_;
	my $name = $hash->{NAME};

	Log3($name, 5, "setData in Dezimal: @w_settings\n");
	my $setdata = pack("C*", @w_settings);
	Log3($name, 5, "sendData in setFanSpeed(): $setdata\n");
	my $tempresponse = sendRequest($hash,$setdata);
	Log3($name, 5, "recvData in setFanSpeed(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in setFanSpeed(): $tempresponse2\n");
	#return &getMode(@FAN_STEP);	getMethode, sollte mal zum Überprüfen genutzt werden ob set richtig funktioniert hat, aber man soll wohl in setXXX undef zurückgeben?!
	return undef;
}

sub setOFFON() {
	# write true/1/OFF or false/0/ON for W_DISABLE_BOOST_AUTOMATIC, W_DISABLE_BYPASS_AUTOMATIC
	my ($hash,@w_settings) = @_;
	my $name = $hash->{NAME};

	Log3($name, 5, "setData in Dezimal: @w_settings\n");
	my $setdata = pack("C*", @w_settings);
	print  "sendData in setOFFON(): $setdata\n";
	my $tempresponse = sendRequest($hash,$setdata);
	Log3($name, 5, "recvData in setOFFON(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0));
	Log3($name, 5, "recvunpackData in setOFFON(): $tempresponse2\n");
	#return &getMode(@FAN_STEP);	getMethode, sollte mal zum Überprüfen genutzt werden ob set richtig funktioniert hat, aber man soll wohl in setXXX undef zurückgeben?!
	return undef;
}

sub setONOFF() {
	# write true/1/ON or false/0/OFF for BOOST, BYPASS, NIGHTCOOLING
	my ($hash,@w_settings) = @_;
	my $name = $hash->{NAME};

	Log3($name, 5, "setData in Dezimal: @w_settings\n");
	my $setdata = pack("C*", @w_settings);
	Log3($name, 5, "sendData in setONOFF(): $setdata\n");
	my $tempresponse = sendRequest($hash,$setdata);
	Log3($name, 5, "recvData in getONOFF(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0));
	Log3($name, 5, "recvunpackData in getONOFF(): $tempresponse2\n");
	#return &getMode(@FAN_STEP);	getMethode, sollte mal zum Überprüfen genutzt werden ob set richtig funktioniert hat, aber man soll wohl in setXXX undef zurückgeben?!
	return undef;
}

sub setMode() {
	# write Anlagenmodus 0/Bedarfsmodus 1/Programm 2/Manuell 3/Aus
	my ($hash,@w_settings) = @_;
	my $name = $hash->{NAME};

	Log3($name, 5, "setData in Dezimal: @w_settings\n");
	my $setdata = pack("C*", @w_settings);
	Log3($name, 5, "sendData in setMode(): $setdata\n");
	my $tempresponse = sendRequest($hash,$setdata);
	Log3($name, 5, "recvData in setMode(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in setMode(): $tempresponse2\n");
	#return &getMode(@FAN_STEP);	getMethode, sollte mal zum Überprüfen genutzt werden ob set richtig funktioniert hat, aber man soll wohl in setXXX undef zurückgeben?!
	return undef;
}


########################################
############# GET Methoden #############
########################################

sub getTemperatur() {
	# read Temperaturen in Grad
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,2));
	Log3($name, 5, "recvunpackData in getTemperatur(): $tempresponse\n");
	my $temperature = hex($tempresponse);	
	return sprintf ('%.02f', $temperature/100);
}

sub getHumidity() {
	# read Luftfeuchtigkeit in Prozent
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getHumidity(): $tempresponse\n");
	my $humidity = hex($tempresponse) * 100 / 255;	
	return sprintf ('%.02f', $humidity);
}

sub getAirInputOutput() {
	# read in AIR_INPUT / AIR_OUTPUT und FAN_SPEED_SUPPLY / FAN_SPPED_EXTRACT in Prozent
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getAirInputOutput(): $tempresponse\n");
	my $inputoutput = hex($tempresponse);	
	return $inputoutput;
}

sub getBatteryLifeTime() {
	# read verbleibende Lebensdauer der Batterien im AirDail-Controller
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getBatteryLifeTime(): $tempresponse\n");
	my $batterylifetime = hex($tempresponse);	
	return sprintf ('%.02f', $batterylifetime);
}

sub getFilterLifeTime() {
	# read verbleibende Lebensdauer der Filter in Prozent
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getFilterLifeTime(): $tempresponse\n");
	my $filterlifetime = hex($tempresponse) * 100 / 255;	
	return sprintf ('%.02f', $filterlifetime);
}

sub getONOFF() {
	# read true/1/ON or false/0/OFF for BOOST, BYPASS, NIGHTCOOLING, FIREPLACE
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getONOFF(): $tempresponse\n");
	my $onoff = hex($tempresponse);
	Log3($name, 5, "recvunpackhexData in getONOFF(): $onoff\n");
	if($onoff == 1){
		return "An"
	}elsif($onoff == 0){
		return "Aus"
	}else {
		die "Unbekannter Paramter $onoff\n";
	}
}

sub getOFFON() {
	# read true/1/OFF or false/0/ON for DISABLE_BOOST_AUTOMATIC, DISABLE_BOOST_AUTOMATIC
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getOFFON(): $tempresponse\n");
	my $onoff = hex($tempresponse);
	Log3($name, 5, "recvunpackhexData in getOFFON(): $onoff\n");
	if($onoff == 0){
		return "An"
	}elsif($onoff == 1){
		return "Aus"
	}else {
		die "Unbekannter Paramter $onoff\n";
	}
}

sub getFanSpeedInRPM() {
	# read aktuelle Lüftergeschwindigkeit in U/min
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,2));
	Log3($name, 5, "recvunpackData in getFanSpeedInRPM(): $tempresponse\n");
	my $fanspeedinrpm = hex($tempresponse);	
	return $fanspeedinrpm;
}

sub getFanSpeed() {
	# read aktuelle Lüftergeschwindigkeit in Stufen von 1-10
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getFanspeed(): $tempresponse\n");
	my $fanspeed = hex($tempresponse);	
	return $fanspeed;
}

sub getModel() {
	# read Modeltyp
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $model = unpack("A*" , substr($data,0));
	Log3($name, 5, "recvunpackData in getModel(): $model\n");
	return $model;
}

sub getMode() {
	# read Anlagenmodus
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,1));
	Log3($name, 5, "recvunpackData in getMode(): $tempresponse\n");
	my $getmode = hex($tempresponse);	
	if($getmode == 0){
		return "Bedarfsmodus"
	}elsif($getmode == 1){
		return  "Programm"
	}elsif($getmode == 2){
		return "Manuell"
	}elsif($getmode == 3){
		return "Aus"
	}else {
		die "Unbekannter Antwortparamter $getmode\n";
	}
}

sub getModelSN() {
	# read Seriennummer
	my ($hash,$data) = @_;
	my $name = $hash->{NAME};

	my $tempresponse = unpack("H*" , substr($data,0,2));
	Log3($name, 5, "recvunpackData in getModelSN(): $tempresponse\n");
	my $modelsn = hex($tempresponse);	
	return $modelsn;
}

sub getCommandKey() {
	my (@command) = @_;
	return unpack('H*', pack('C*' x @command, @command));
}

####################### SEND Request #######################
# VERBINDUNGSAUFBAU ZUR ANLAGE... 
############################################################

# SEND Request for SET
sub sendRequest(){
	my ($hash,@sendData) = @_;
	my $name = $hash->{NAME};

	my $data = pack("C*" x @sendData, @sendData);

	Log3($name, 5, "sendData in sendRequest(): ".join(',', map(sprintf("0x%02x", $_), @sendData)));
    ::DevIo_SimpleWrite( $hash, $data, 0 );
}

# SEND Request for GET
sub sendNextRequest(){
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $queueRef = $hash->{helper}{commandQueue};

	# queue is empty - nothing to do
	return if (!@$queueRef);

	my @nextCmd = @{ shift(@$queueRef) };
	my $data = pack('C*' x @nextCmd, @nextCmd);
	my $unpackedData = unpack('H*', $data);

	Log3($name, 4, "sendData in sendRequest(): $unpackedData");
    ::DevIo_SimpleWrite( $hash, $data, 0 );

	$hash->{LastCommand} = $unpackedData;
}

1;

=pod
=begin html

<a name="AirUnit"></a>
<h3>AirUnit</h3>
<ul>
    <i>AirUnit</i> implements a FHEM device to control Danfoss AirUnits (a1,a2,w1,w2). Tested only with w2 (Feb 2021). 
    With this module it is possible to control the most useful functions of your ventilation system.
    <br><br>
    <a name="AirUnitdefine"></a>
    <b>Define</b>
    <ul>
		<code>define &lt;name&gt; AirUnit &lt;IP-address[:Port]&gt; [poll-interval]</code><br>
		If the poll interval is omitted, it is set to 300 (seconds). Smallest possible value is 30.
		<br>
		Usually, the port needs not to be defined.
		<br>
		Example: <code>define myAirUnit AirUnit 192.168.0.12 600</code>
    </ul>
    <br>
    
    <a name="AirUnitset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> different values to any of the following options. 
        <br><br>
        Options:
        <ul>
				<li><i>Modus</i><br>
                  You can choose between<br>
						<i>"Bedarfsmodus"</i>, for automatic mode<br>
						<i>"Programm"</i>, you can define a programm in your AirDail-Controller and choose one.<br>
						<i>"Manuell"</i>, you can set the steps for the fans manually (only in manual mode). Bypass and Boost are in automatic mode.<br>
						<i>"Aus"</i>, the system is off for 24 hours, after this time, the system starts in automatic mode with fanstep 1.
				<li><i>Lüfterstufe</i><br>
                  You can set the steps for the fans manually. (only in manual mode)</li>
				<li><i>Boost</i><br>
                  You can activate/deactive the Boost-Option of your ventilation system. You can configure this mode in your AirDail-Controller, the standard fanstep 10 for 3 hours.<br>
				  It is useful if you need more Air e.g. in case of cooking or a party with more people.</li>
				<li><i>Bypass</i><br>
                  You can activate/deactive the Bypass-Option of you ventilations systems. Its a cooling function, the heat exchanger will be deactivated.<br>
				  You can configure this mode in your AirDail-Controller, the standard time is 3 hours.<br>
				  <b>You can´t activte it, if the outdoor temperature is under 5°C.</b></li>
				<li><i>Nachtkühlung</i><br>
                  You can activate/deactive the nightcooling option of you ventilations systems. You can configure this in your AirDail-Controller.</li>
				<li><i>automatischer Boost</i><br>
                  You can activate/deactive the automatic Boost-Option of you ventilations systems. Its automaticly activated, if the humidity increase very strong, then it runs for 30min.</li>
				<li><i>automatischer Bypass</i><br>
                  You can activate/deactive the automatic Bypass-Option of you ventilations systems. Its automaticly activated, if the outdoor temperature and room temperature are higher then the configured values.<br>
				  You can configure this mode in your AirDail-Controller.</li>
				<li><i>Intervall</i><br>
                  You can setup the refresh intervall of your readings. Minimum 30 seconds.</li>
        </ul>
    </ul>
    <br>

    <a name="AirUniget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can <i>get</i> the value of any of the options described in 
        <a href="#Helloset">paragraph "Set" above</a>. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
    </ul>
    <br>
    
    <a name="AirUniattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i>formal</i> no|yes<br>
                When you set formal to "yes", all output of <i>get</i> will be in a
                more formal language. Default is "no".
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
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
		InternalTimer
		RemoveInternalTimer
    ));
};

GP_Export(
    qw(
      Initialize
      )
);

my $Version = '0.0.3.7 - Feb 2021';

####################### GET Paramter #######################  Das sind die Zahlen die gesendet werden müssen, damit man die Informationen erhält.

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
my @COOKERHOOD = (0x01, 0x04, 0x15, 0x34);				#### REGISTER_1_READ, COOKERHOOD ON/OFF

my @MODE = (0x01, 0x04, 0x14, 0x12);					#### REGISTER_1_READ, MODE
my @FAN_STEP = (0x01, 0x04, 0x15, 0x61);				#### REGISTER_1_READ, FANSPEED / FANSTUFE in MANUELL - MODE

my @FANSPEED_IN_RPM = (0x04, 0x04, 0x14, 0x50);			#### REGISTER_1_READ, FANSPEED_IN_RPM
my @FANSPEED_OUT_RPM = (0x04, 0x04, 0x14, 0x51);		#### REGISTER_1_READ, FANSPEED_OUT_RPM

my @MODEL = (0x01, 0x04, 0x15, 0xe5);					#### REGISTER_1_READ, MODEL
my @MODEL_SN = (0x04, 0x04, 0x00, 0x25);				#### REGISTER_4_READ, MODEL SERIALNUMBER

####################### SET Paramter #######################	Das sind die Zahlen die gesendet werden müssen + eine 5. (die Option), damit man etwas bewirken kann.

my @W_BOOST = (0x01, 0x06, 0x15, 0x30);						#### REGISTER_1_WRITE, BOOST ON/OFF
my @W_BYPASS = (0x01, 0x06, 0x14, 0x63);					#### REGISTER_1_WRITE, BYPASS ON/OFF
my @W_NIGHTCOOLING = (0x01, 0x06, 0x15, 0x71);				#### REGISTER_1_WRITE, NIGHTCOOLING ON/OFF
my @W_DISABLE_BOOST_AUTOMATIC = (0x01, 0x06, 0x17, 0x02);	#### REGISTER_1_WRITE, BOOST_AUTOMATIC ON/OFF
my @W_DISABLE_BYPASS_AUTOMATIC = (0x01, 0x06, 0x17, 0x06);	#### REGISTER_1_WRITE, BYPASS_AUTOMATIC ON/OFF
my @W_MODE = (0x01, 0x06, 0x14, 0x12);						#### REGISTER_1_WRITE, MODE
my @W_FAN_STEP = (0x01, 0x06, 0x15, 0x61);					#### REGISTER_1_WRITE, FAN_STEP
my @W_FIREPLACE = (0x01, 0x06, 0x17, 0x07);					#### REGISTER_1_WRITE, FIREPLACE ON/OFF
my @W_COOKERHOOD = (0x01, 0x06, 0x15, 0x34);				#### REGISTER_1_WRITE, COOKERHOOD ON/OFF

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
	$interval = 10 if( $interval < 10 );

	$hash->{NAME} = $name;
	$hash->{ModuleVersion} = $Version;

	$hash->{STATE} = "Initializing";
	if ( $host =~ /(.*):(.*)/ ) {
		$host = $1;
		$port = $2;
		$hash->{fhem}{portDefined} = 1;
	}
	else {
		$hash->{fhem}{portDefined} = 0;
	}
	$hash->{INTERVAL} = $interval;
	$hash->{NOTIFYDEV} = "global";
	$hash->{DeviceName} = join(':', $host, $port);

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
  
  # read the available data
  my $buf = ::DevIo_SimpleRead($hash);
  
  # stop processing if no data is available (device disconnected)
  return if(!defined($buf));
  
  Log3($name, 5, "AirUnit ($name) - received: $buf");
  Log3($name, 5, "AirUnit ($name) - received as hex: ".join(' ', unpack('(H2)*', $buf)));

  #
  # do something with $buf, e.g. generate readings, send answers via DevIo_SimpleWrite(), ...
  #
   
}

########################################
# will be executed if connection establishment fails (see DevIo_OpenDev())
sub Callback()
{
    my ($hash, $error) = @_;
    my $name = $hash->{NAME};

	# create a log emtry with the error message
	Log3($name, 5, "AirUnit ($name) - error while connecting: $error") if($error);

	GetUpdate($hash);

    return undef;
}

######################################## todo
# Bei Get müssen immer nur 4 Zahlen gesendet werden

sub Get() {
	
  my ($hash, $name, $cmd, @val ) = @_;
  
  if($cmd eq 'update') {
	  DoUpdate($hash) if (::DevIo_IsOpen($hash));				##### NEU in Version 0.0.3.1, einfach mal so updaten			
   }
   elsif($cmd eq 'nothing') {
      # Log3 $name, 3, "get $name $cmd";
      if (int @val !=1000) {
         my $msg = "Wrong number of parameter (".int @val.")in get $name $cmd";
         Log3($name, 3, $msg);
         return $msg;
      }
   }
   elsif( $cmd eq 'rawData') {
	  # Log3 $name, 3, "get $name $cmd";
      if (int @val !=4000 ) {
         my $msg = "Wrong number of parameter (".int @val.")in get $name $cmd";
         Log3($name, 3, $msg);
         return $msg;
      }
   }

   my $list = " update:noArg"
			. " nothing"
			. " rawData";
       
   return "Unknown argument $cmd, choose one of $list";
}

######################################## todo
# Bei Set müssen immer 5 Zahlen gesendet werden

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
		#setMode($hash, @w_settings);		# hier muss quasi @W_MODE + der Modus gesendet werden also zB (0x01, 0x06, 0x14, 0x12, 0x00);		
		sendRequest($hash, @w_settings);
		return undef;
	}
	# elsif ($cmd eq 'Lüfterstufe') {
		# Log3($name, 3, "set $name $cmd $val");
		# my $myMode = getMode($hash, @MODE);			# Prüfen, ob der Mode auf "Manuell" steht, sonst macht der Rest keinen Sinn.
		# if ($val <= 10 || $val >= 0 and $myMode eq "Manuell"){
			# @w_settings = (@W_FAN_STEP, $val);
			# #setFanSpeed($hash, @w_settings);
			# sendRequest($hash, @w_settings);
		# }else{
			# return "Lüftung ist nicht im manuellen Modus, sondern in: $myMode";
		# }
	#}
	elsif ($cmd eq 'Lüfterstufe') {
		Log3($name, 3, "set $name $cmd $val");
		if ($val <= 10 || $val >= 1){
			@w_settings = (@W_FAN_STEP, $val);
			#setFanSpeed($hash, @w_settings);
			sendRequest($hash, @w_settings);
		}else{	
			return "Lüftung ist nicht im manuellen Modus";
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
		#setONOFF($hash, @w_settings);
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
			#setONOFF($hash, @w_settings);
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Nachtkühlung'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_NIGHTCOOLING, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_NIGHTCOOLING, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		#setONOFF($hash, @w_settings);
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Feuerstätte'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_FIREPLACE, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_FIREPLACE, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		#setONOFF($hash, @w_settings);
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'Dunstabzugshaube'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_COOKERHOOD, 0x01);
		}elsif($val eq "off"){
			@w_settings = (@W_COOKERHOOD, 0x00);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		#setONOFF($hash, @w_settings);
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif ($cmd eq 'automatischerBoost'){
		Log3($name, 3, "set $name $cmd $val");
		if($val eq "on"){
			@w_settings = (@W_DISABLE_BOOST_AUTOMATIC, 0x00);
		}elsif($val eq "off"){
			@w_settings = (@W_DISABLE_BOOST_AUTOMATIC, 0x01);
		}else {
			die "Fehlerhafter Paramter $val für Setting $cmd\n";
		}
		#setOFFON($hash, @w_settings);
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
		#setOFFON($hash, @w_settings);
		sendRequest($hash, @w_settings);
		return undef;
	}
	elsif($cmd eq 'Intervall' && int(@_)==4 ) {
      Log3($name, 3, "set $name $cmd $val");
      $val = 10 if( $val < 10 );
      $hash->{INTERVAL}=$val;
      return "Intervall wurde auf $val Sekunden gesetzt.";
   }
	
	my $list = " Modus:Bedarfsmodus,Programm,Manuell,Aus "
		." Lüfterstufe:slider,1,1,10 "
		." Boost:on,off "
		." Bypass:on,off "
		." Nachtkühlung:on,off "
		." Feuerstätte:on,off "
		." Dunstabzugshaube:on,off "
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
# Diese GetUpdate Methode läuft jetzt nach dem ersten Aufruf im Define intervallbasiert und ruft dabei sich selber immer wieder auf und setzt den Timer neu
# DoUpdate sollte dann wohl die Readings setzen... UpdateAborted etwas bei Fehlerhaften Aufruf machen
# 
# mit unless(exists($hash->{helper}{RUNNING_PID}) wird geprüft ob es noch eine laufenden BlockingCall gib.

sub GetUpdate() {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer($hash);
	InternalTimer(gettimeofday()+$hash->{INTERVAL}, \&GetUpdate, $hash, 0);
	return undef if( AttrVal($name, "disable", 0 ) == 1 );

	DoUpdate($hash) if (::DevIo_IsOpen($hash));
}
########################################
#jetzt ist vieles nur c+p
########################################

########################################
# habe bei DoUpdate die Readings füllen wollen
########################################

sub DoUpdate(){

	my ($hash) = @_;
	my $name = $hash->{NAME};
		
	# Update readings
	
	# readingsBeginUpdate($hash);
 
	# get_Temperature_Value

	sendRequest($hash, @OUTDOOR_TEMPERATURE);
	sendRequest($hash, @ROOM_TEMPERATURE);
	sendRequest($hash, @SUPPLY_TEMPERATURE);
	sendRequest($hash, @EXTRACT_TEMPERATURE);
	sendRequest($hash, @EXHAUST_TEMPERATURE);

	# my $outdoorTemperature = getTemperatur($hash, @OUTDOOR_TEMPERATURE);
	# Log3($name, 5, "OUTDOOR_TEMPERATURE after  getTemperatur(): $outdoorTemperature\n"); 
	# my $roomTemperature = getTemperatur($hash, @ROOM_TEMPERATURE);
	# Log3($name, 5, "ROOM_TEMPERATURE from AirDail after  getTemperatur(): $roomTemperature\n"); 
	# my $supplyTemperature = getTemperatur($hash, @SUPPLY_TEMPERATURE);
	# Log3($name, 5, "SUPPLY_TEMPERATURE after  getTemperatur(): $supplyTemperature\n"); 
	# my $extractTemperature = getTemperatur($hash, @EXTRACT_TEMPERATURE);
	# Log3($name, 5, "EXTRACT_TEMPERATURE  getTemperatur(): $extractTemperature\n"); 
	# my $exhaustTemperature = getTemperatur($hash, @EXHAUST_TEMPERATURE);
	# Log3($name, 5, "EXHAUST_TEMPERATURE after  getTemperatur(): $exhaustTemperature\n"); 

	# readingsBulkUpdate( $hash, "Außenlufttemperatur", $outdoorTemperature);
	# readingsBulkUpdate( $hash, "Raumtemperatur AirDail", $roomTemperature);
	# readingsBulkUpdate( $hash, "Zulufttemperatur", $supplyTemperature);
	# readingsBulkUpdate( $hash, "Ablufttemperatur", $extractTemperature);
	# readingsBulkUpdate( $hash, "Abluft Temperatur", $exhaustTemperature);

	# get_Value_in_Percent

	sendRequest($hash, @HUMIDITY);
	sendRequest($hash, @AIR_INPUT);
	sendRequest($hash, @AIR_OUTPUT);
	sendRequest($hash, @FAN_SPEED_SUPPLY);
	sendRequest($hash, @FAN_SPPED_EXTRACT);

	# my $humidity = getHumidity($hash, @HUMIDITY);
	# Log3($name, 5, "HUMIDITY after  getHumidity(): $humidity %\n"); 
	# my $input = getAirInputOutput($hash, @AIR_INPUT);
	# Log3($name, 5, "INPUT after  getAirInputOutput(): $input %\n");
	# my $output = getAirInputOutput($hash, @AIR_OUTPUT);
	# Log3($name, 5, "OUTPUT after  getAirInputOutput(): $output %\n");
	# my $zufluftStufe = getAirInputOutput($hash, @FAN_SPEED_SUPPLY);
	# Log3($name, 5, "ZUFLUFT_STUFE after  getAirInputOutput(): $zufluftStufe %\n");
	# my $abluftStufe = getAirInputOutput($hash, @FAN_SPPED_EXTRACT);
	# Log3($name, 5, "ABLUFT_STUFE after  getAirInputOutput(): $abluftStufe %\n");

	# readingsBulkUpdate( $hash, "Luftfeuchtigkeit", $humidity);
	# readingsBulkUpdate( $hash, "Lüftereinstellung Zuluft Grundstufe", $input);
	# readingsBulkUpdate( $hash, "Lüftereinstellung Abluft Grundstufe", $output);
	# readingsBulkUpdate( $hash, "Lüftereinstellung Zuluft Stufe", $zufluftStufe);
	# readingsBulkUpdate( $hash, "Lüftereinstellung Abluft Stufe", $abluftStufe);

	sendRequest($hash, @FILTER_LIFE);
	sendRequest($hash, @BATTERY_LIFE);

	# my $filterLifetime = getFilterLifeTime($hash, @FILTER_LIFE);
	# Log3($name, 5, "FILTERLIFETIME after  getFilterLifeTime(): $filterLifetime %\n");
	# my $batteryLifetime = getBatteryLifeTime($hash, @BATTERY_LIFE);			 
	# Log3($name, 5, "BATTERYLIFETIME after  getBatteryLifeTime(): $batteryLifetime %\n");

	# readingsBulkUpdate( $hash, "Lebensdauer Filter im Gerät", $filterLifetime);
	# readingsBulkUpdate( $hash, "Lebensdauer Batterie in AirDail", $batteryLifetime);

	# get_ON_or_OFF 

	sendRequest($hash, @BOOST);
	sendRequest($hash, @BYPASS);
	sendRequest($hash, @NIGHTCOOLING);
	sendRequest($hash, @BOOST_AUTOMATIC);
	sendRequest($hash, @BYPASS_AUTOMATIC);

	# my $boost = getONOFF($hash, @BOOST);
	# Log3($name, 5, "BOOST after  getONOFF(): $boost\n"); 
	# my $bypass = getONOFF($hash, @BYPASS);
	# Log3($name, 5, "BYPASS after  getONOFF(): $bypass\n"); 
	# my $nightcooling = getONOFF($hash, @NIGHTCOOLING);
	# Log3($name, 5, "NIGHTCOOLING after  getONOFF(): $nightcooling\n");
	# #invert
	# my $boostAutomatic = getOFFON($hash, @BOOST_AUTOMATIC);
	# Log3($name, 5, "BOOST_AUTOMATIC after  getOFFON(): $boostAutomatic\n");
	# #invert
	# my $bypassAutomatic = getOFFON($hash, @BYPASS_AUTOMATIC);
	# Log3($name, 5, "BYPASS_AUTOMATIC after  getOFFON(): $bypassAutomatic\n");

	# readingsBulkUpdate( $hash, "Boost", $boost);
	# readingsBulkUpdate( $hash, "Bypass", $bypass);
	# readingsBulkUpdate( $hash, "Nachtkühlung", $nightcooling);
	# readingsBulkUpdate( $hash, "automatischer Boost", $boostAutomatic);
	# readingsBulkUpdate( $hash, "automatischer Bypass", $bypassAutomatic);

	# get_FanSpeed_in_RPM

	sendRequest($hash, @FANSPEED_IN_RPM);
	sendRequest($hash, @FANSPEED_OUT_RPM);

	# my $fanspeedInRpmIn = getFanSpeedInRPM($hash, @FANSPEED_IN_RPM);
	# Log3($name, 5, "FANSPEEDinRPMin after  getFanSpeedInRPM(): $fanspeedInRpmIn\n");
	# my $fanspeedInRpmOut = getFanSpeedInRPM($hash, @FANSPEED_OUT_RPM );
	# Log3($name, 5, "FANSPEEDinRPMout after  getFanSpeedInRPM(): $fanspeedInRpmOut\n");

	# readingsBulkUpdate( $hash, "FANSPEEDinRPMin", $fanspeedInRpmIn);
	# readingsBulkUpdate( $hash, "FANSPEEDinRPMout", $fanspeedInRpmOut);

	#get_String

	sendRequest($hash, @MODEL);

	# my $model = getModel($hash, @MODEL);
	# Log3($name, 5, "MODELL after  getModel(): $model\n");

	# readingsBulkUpdate( $hash, "model", $model);

	# get_Value

	sendRequest($hash, @MODE);
	sendRequest($hash, @MODEL_SN);
	sendRequest($hash, @FAN_STEP);

	# my $mode = getMode($hash, @MODE);
	# Log3($name, 5, "MODE after  getMode(): $mode\n");
	# my $modelSn = getModelSN($hash, @MODEL_SN);
	# Log3($name, 5, "MODEL_SN after  getModelSN(): $modelSn\n");
	# my $fanstufe = getFanSpeed($hash, @FAN_STEP);
	# Log3($name, 5, "FANSTUFE after  getFanSpeed() Stufe: $fanstufe\n");

	# readingsBulkUpdate( $hash, "Modus", $mode);
	# readingsBulkUpdate( $hash, "Seriennummer", $modelSn);
	# readingsBulkUpdate( $hash, "Lüfterstufe", $fanstufe);
		 
	# readingsEndUpdate($hash,1);
}

####################### SET Methoden #######################
# Welche Übergabeparameter bekommen die SETs??? 


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


####################### GET Methoden #######################
# Welche Übergabeparameter bekommen die GETs??? 

sub getOFFON() {
	# read true/1/OFF or false/0/ON for DISABLE_BOOST_AUTOMATIC, DISABLE_BOOST_AUTOMATIC
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getOFFON(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getOFFON(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getOFFON(): $tempresponse2\n");
	my $onoff = hex(unpack("H*" , substr($tempresponse,0,1)));
	print  "recvunpackhexData in getOFFON(): $onoff\n";
	if($onoff == 0){
		return "An"
	}elsif($onoff == 1){
		return "Aus"
	}else {
		die "Unbekannter Paramter $onoff\n";
	}
}

sub getONOFF() {
	# read true/1/ON or false/0/OFF for BOOST, BYPASS, NIGHTCOOLING
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getONOFF(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getONOFF(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getONOFF(): $tempresponse2\n");
	my $onoff = hex(unpack("H*" , substr($tempresponse,0,1)));
	print  "recvunpackhexData in getONOFF(): $onoff\n";
	if($onoff == 1){
		return "An"
	}elsif($onoff == 0){
		return "Aus"
	}else {
		die "Unbekannter Paramter $onoff\n";
	}
}

sub getModelSN() {
	# read Seriennummer
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getModelSN(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getModelSN(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,2));
	Log3($name, 5, "recvunpackData in getModelSN(): $tempresponse2\n");
	my $modelsn = hex(unpack("H*" , substr($tempresponse,0,2)));	
	return $modelsn;
}

sub getFanSpeedInRPM() {
	# read Lüftergeschwindigkeit Input / Output  in U/min
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getFanSpeedInRPM(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getFanSpeedInRPM(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,2));
	Log3($name, 5, "recvunpackData in getFanSpeedInRPM(): $tempresponse2\n");
	my $fanspeedinrpm = hex(unpack("H*", substr($tempresponse,0,2)));	
	return $fanspeedinrpm;
}

sub getAirInputOutput() {
	# read in Air Input / Output  in Prozent
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getAirInputOutput(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getAirInputOutput(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getAirInputOutput(): $tempresponse2\n");
	my $inputoutput = hex(unpack("H*", substr($tempresponse,0,1)));	
	return $inputoutput;
}

sub getBatteryLifeTime() {
	# read batterylifetime 														<<<<<< Muss nochmal getestet werden, da Controller aktuell am Strom hängt
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getBatteryLifeTime(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getBatteryLifeTime(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getBatteryLifeTime(): $tempresponse2\n");
	my $batterylifetime = hex(unpack("H*", substr($tempresponse,0,1)));	
	return sprintf ('%.02f', $batterylifetime);
}

sub getMode() {
	# read Anlagenmodus
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getMode(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getMode(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getMode(): $tempresponse2\n");
	my $getmode = hex(unpack("H*", substr($tempresponse,0,1)));	
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

sub getModel() {
	# read Modeltyp
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getModel(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getModel(): $tempresponse\n");
	my $tempresponse2 = unpack("A*" , substr($tempresponse,0));
	Log3($name, 5, "recvunpackData in getModel(): $tempresponse2\n");
	my $model = unpack("A*" , substr($tempresponse,1));	
	return $model;
}

sub getFilterLifeTime() {
	# read verbleibende Filterlebensdauer in Prozent
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getFilterLifeTime(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getFilterLifeTime(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getFilterLifeTime(): $tempresponse2\n");
	my $filterlifetime = hex(unpack("H*", substr($tempresponse,0,1))) * 100 / 255;	
	return sprintf ('%.02f', $filterlifetime);
}

sub getFanSpeed() {
	# read aktueller Lüftergeschwindigskeitsstufe von 1-10
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getFanspeed(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getFanspeed(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getFanspeed(): $tempresponse2\n");
	my $fanspeed = hex(unpack("H*", substr($tempresponse,0,1)));	
	return $fanspeed;
}

sub getTemperatur() {
	# read Temperaturen
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getTemperatur(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getTemperatur(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,2));
	Log3($name, 5, "recvunpackData in getTemperatur(): $tempresponse2\n");
	my $temperature = hex(unpack("H*" , substr($tempresponse,0,2)));	
	return sprintf ('%.02f', $temperature/100);
}

sub getHumidity() {
	# read Luftfeuchtigkeit
	my ($hash,@r_setting) = @_;
	my $name = $hash->{NAME};

	my $sendData = pack("C*" x 4, @r_setting);
	Log3($name, 5, "sendData in getHumidity(): $sendData\n");
	my $tempresponse = sendRequest($hash,$sendData);
	Log3($name, 5, "recvData in getHumidity(): $tempresponse\n");
	my $tempresponse2 = unpack("H*" , substr($tempresponse,0,1));
	Log3($name, 5, "recvunpackData in getHumidity(): $tempresponse2\n");
	my $humidity = hex(unpack("H*", substr($tempresponse,0,1))) * 100 / 255;	
	return sprintf ('%.02f', $humidity);
}


####################### SEND Request #######################
# VERBINDUNGSAUFBAU ZUR ANLAGE... 
# $sendData soll immer der Übergabeparameter aus setXXX oder getXXX sein mit 5 oder 4 Zahlen.

sub sendRequest(){
	my ($hash,@sendData) = @_;
	my $name = $hash->{NAME};

	my $data = pack("C*" x @sendData, @sendData);

	Log3($name, 5, "sendData in sendRequest(): ".join(',', map(sprintf("0x%02x", $_), @sendData)));
    ::DevIo_SimpleWrite( $hash, $data, 0 );
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
		If the poll interval is omitted, it is set to 300 (seconds). Smallest possible value is 10.
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
                  You can setup the refresh intervall of your readings.</li>
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
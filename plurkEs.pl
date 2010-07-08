#!/usr/bin/perl 
#
# Peteris Krumins (peter@catonmat.net)
# http://www.catonmat.net  --  good coders code, great reuse
#
# Command line plurker versión Español.
#
# Version translated to Spanish: 0.1 
# Pável Oropeza
# http://cognus.ath.cx
# 
# Version 1.0, 2009.12.02: fun release
#
# TODO Ideas:
# * Save cookie after successful login so that the program
#   didn't log in for each plurk.
# 
#Recomendacion: 
#Puedes establecer tu nombre de usuario y contraseña en forma permanente
#y plurkear de esta forma: plurkEs.pl -a <action> <message>
#Nombre de usuario o apodo:
#use constant USERNAME => 'apodo';
use constant USERNAME => 'zahori';
#Contraseña:
#use constant PASSWORD => 'contraseña';
use constant PASSWORD => 'antofagasta24';

##############################################################
# Cuidado: A PARTIR DE ESTA PARTE YA NO ES NECESARIO EDITAR! #
##############################################################
# En caso de que no desees ingresar tu apodo y contraseña
#plurkea de esta forma:
#plurkEs.pl -u <username> -p <password> -a <action> <message>
my $usage = <<EOL;
Usage:
 plurkEs.pl -u <username> -p <password> -a <action> <message>
<ACTION> ama, prefiere, espera, pregunta, tiene, ..., etc.
                   
La acción por defecto es 'says' (Hay que cambiarlo por 'dice', pero eso después :-).
Si omites el parámetro -a el plurk se puede hacer como:

    $ plurkEs.pl <message>

#Compartir videos de youtube, enlaces y fotos es de la siguiente forma:
plurkEs.pl -a shares http://... \(Texto\)
plurkEs.pl -a shares http://www.youtube.com/watch?v=QcPvHkXfqoc

#Algunos emoticonos de uso frecuente y su uso:
#(wave)
#(music)
#:-o
#(hungry)
#(gym)
#Para decir tengo hambre con emoticono:
plurkEs.pl tengo \(hungry\)

<Message> está limitado a no más de 140 caracteres.
EOL

use strict;
use warnings;
use WWW::Mechanize;

use constant VERSION => '1.0';

use constant DEBUG => 0;
use constant ACTIONS =>
    #qw(ama prefiere comparte ofrece odia quiere desea necesita
    #   hará espera pregunta tiene estaba pregunta siente
    #   piensa dice está);
       
    qw(loves likes shares gives hates wants wishes needs
       will hopes asks has was wonders feels
       thinks says is);   

my ($username, $password, $action, $message) = parse_args();
print "$username\@$password $action '$message'\n" if DEBUG;

my $plurk = Plurk->new;

print "Ingresando al Plurk...\n";
$plurk->login($username, $password);
die $plurk->error if $plurk->error;

print "Plurkeando ...\n";
$plurk->plurk($action, $message);
die $plurk->error if $plurk->error;

print "Plurkeado: $username $action $message\n";

sub parse_args {
    my ($username, $password, $action);

    # Extract and parse command line arguments
    my $argstr = join ' ', @ARGV;
    if ($argstr =~ /-u ?([^ ]+)/) { # Username -u
        $username = $1;
        $argstr =~ s/-u ?([^ ]+)//; # Wipe username
    }
    else {
        $username = USERNAME;
    }

    if ($argstr =~ /-p ?([^ ]+)/) { # Password -p
        # Assumes password does not contain spaces
        $password = $1;
        $argstr =~ s/-p ?([^ ]+)//; # Wipe password
    }
    else {
        $password = PASSWORD;
    }

    if ($argstr =~ /-a ?([^ ]+)/) {
        $action = $1;
        unless (grep { $_ eq $action } ACTIONS) {
            print "Error. Esta acción no está incluida: '$action'\n";
            print "Acciones incluidas: ";
            print join(', ', ACTIONS), "\n";
            exit 1;
        }
        $argstr =~ s/-a ?([^ ]+)//; # Wipe action
    }
    else {
        $action = 'says';
    }

    $argstr =~ s/^ +//; # Wipe leading spaces from message
    unless (length $argstr) {
        print "Error. No se ingresó ningún mensaje\n";
        exit 1;
    }
    if (length $argstr > 140) {
        print "Error: El mensaje sobrepasa los 140 caracteres\n";
        print "Tiene ", length $argstr, " caracteres demás. Por favor recortalo!",
              length($argstr) - 140, " caractere(s)!\n";
        exit 1;
    }
    
    return ($username, $password, $action, $argstr);
}

sub usage {
    print "Command line plurker by Peteris Krumins (peter\@catonmat.net)\n";
    print "http://www.catonmat.net  --  good coders code, great reuse\n";
    print "\n";
    print $usage;
    exit 1;
}

package Plurk;

use LWP::UserAgent;

sub new {
    bless {}, shift;
}

sub _init_mech {
    my $self = shift;
    my $mech = WWW::Mechanize->new(
        timeout   => 10,
        agent     => 'command line plurker/v'.main::VERSION,
        autocheck => 0
    );
    $self->{mech} = $mech;
}

sub login {
    my $self = shift;
    my ($username, $password) = @_;
    $self->_init_mech();
    $self->{mech}->post('http://www.plurk.com/Users/login', {
        nick_name => $username,
        password  => $password
    });
    unless ($self->{mech}->success) {
        $self->_mech_error("Error. No se puede ingrear a Plurk.");
        return;
    }
    unless ($self->{mech}->content =~ /var SETTINGS/) {
        $self->error("Error al ingresar a Plurk. Revisa tu nombre de usuario/password.");
        return;
    }
    $self->{uid}  = $self->_extract_uid;
    $self->{lang} = $self->_extract_lang;
}

sub plurk {
    my ($self, $action, $msg) = @_;

    $self->{mech}->post('http://www.plurk.com/TimeLine/addPlurk', {
        qualifier   => $action,
        content     => $msg,
        uid         => $self->{uid},
        no_comments => 0,
        lang        => $self->{lang}
    });
    unless ($self->{mech}->success) {
        $self->_mech_error("Falló el plurkeo.");
        return;
    }
}

sub _mech_error {
    my ($self, $error) = @_;
    $self->error($error, "HTTP Code:", $self->{mech}->status(), ".",
                         "Content:", substr($self->{mech}->content, 0, 512));
}

sub _extract_uid {
    my $self = shift;
    return $self->_extract_stuff('SETTINGS', 'user_id', '(\d+)');
}

sub _extract_lang {
    my $self = shift;
    return $self->_extract_stuff('GLOBAL', 'default_lang', '"([^"]+)"');
}

sub _extract_stuff {
    my ($self, $section, $name, $rx) = @_;
    if ($self->{mech}->content =~ /$section.+"$name": $rx/) {
        return $1;
    }
    else {
        $self->error("Falló al extraer $name.");
    }
}

sub error {
    my $self = shift;
    return $self->{error} unless @_;
    $self->{error} = "@_";
}
%{
#include <stdio.h>
#include <string.h>

const int NDIAS = 6;
const int NHORAS = 8;
const int NCIELOS = 11;
const int NTEMPS = 4;
const int MAXMUN = 10;

int i= 0;
int ihora = 0;
int icielo = 0;
int itemp = 0;
int nmun = 0;

char* dias[6];
char* horas[8];
char* cielos[11];
char* temps[4];
char* lluvias[11];
char* minimas[6];
char* maximas[6];
char * urls[10];
char * nombres[10];


void copiar_yytext(char** destino);
void reporte ();
int elegir_resultado();
void liberar_memoria();
%}

%s PREDICCION DIAS DIA HORAS CIELO TEMP PRELLUVIA LLUVIA PREMINMAX MINMAX MIN MAX
%s BUSQUEDA RESULTADOS URL PRENOMBRE NOMBRE

%%

	/* Comprobar si se trata de la pagina de busqueda o la de municipio */

\<table\ id=\"tabla_prediccion\".*\>	{BEGIN PREDICCION; nmun=1;}

"Buscador de municipios"				{BEGIN BUSQUEDA;}

	/* Pagina de prevision del municipio */


<PREDICCION>cabecera_loc_niv1			{BEGIN DIAS;}
<DIAS>title=\"							{BEGIN DIA;}
<DIA>[^\"]+								{BEGIN DIAS; copiar_yytext(&dias[i]); i++;}
<DIAS>\<\/tr\>							{BEGIN PREDICCION; i=0;}


<PREDICCION>cabecera_loc_niv2			{BEGIN HORAS;}
<HORAS>[0-9]+&ndash;[0-9]+&nbsp;h		{copiar_yytext(&horas[ihora]); ihora++;}

<HORAS>alt=\"							{BEGIN CIELO;}
<CIELO>[^\"]+							{BEGIN HORAS; copiar_yytext(&cielos[icielo]); icielo++;}

<HORAS>title=\"Temperatura				{BEGIN TEMP;}
<TEMP>-?[0-9]+&deg;C					{BEGIN HORAS; int len=strlen(yytext)-6; temps[itemp]=malloc(len+1);
										strncpy(temps[itemp], yytext, len); temps[itemp][len]='\0'; itemp++;}

<HORAS>\<\/tr\>							{BEGIN PREDICCION;}


<PREDICCION>title=\"Probabilidad		{BEGIN PRELLUVIA;}
<PRELLUVIA>\<\/tr\>						{BEGIN LLUVIA;}
<LLUVIA>[0-9]+%							{copiar_yytext(&lluvias[i]); i++;}
<LLUVIA>\<\/tr\>						{BEGIN PREDICCION; i=0;}


<PREDICCION>title=\"Temperatura			{BEGIN PREMINMAX;}
<PREMINMAX>\<\/tr\>						{BEGIN MINMAX;}
<MINMAX>texto_azul\"\>					{BEGIN MIN;}
<MIN>-?[0-9]+							{BEGIN MINMAX; copiar_yytext(&minimas[i]);}
<MINMAX>texto_rojo\"\>					{BEGIN MAX;}
<MAX>-?[0-9]+							{BEGIN MINMAX; copiar_yytext(&maximas[i]); i++;}
<MINMAX>\<\/tr\>						{BEGIN PREDICCION; i=0;}


<PREDICCION>\<\/table\>					{BEGIN 0;}

	/* Pagina de busqueda de municipios */


<BUSQUEDA>"No se encontraron resultados"	{BEGIN 0;}
<BUSQUEDA>notas_busqueda				{BEGIN RESULTADOS;}

<RESULTADOS>href=\"						{BEGIN URL;}
<URL>[^\"]+								{BEGIN PRENOMBRE; copiar_yytext(&urls[nmun]);}
<PRENOMBRE>\"[ ]?\>						{BEGIN NOMBRE;}
<NOMBRE>[^\<]+							{BEGIN RESULTADOS; copiar_yytext(&nombres[nmun]); nmun++; if(nmun==MAXMUN) BEGIN 0;}

<RESULTADOS>\<\/ul\>					{BEGIN 0;}

.|\n									;

%%

int main (int argc, char *argv[]) {

	// Numero de argumentos incorrecto
	if (argc != 2) {
		printf("Uso: %s municipio\n", argv[0]);
		exit(2);
	}

	// Variables
	const char* wget = "wget -q -O web-aemet '";
	const char* url_busqueda = "http://www.aemet.es/es/eltiempo/prediccion/municipios?modo=and&orden=n&tipo=sta&str=";
	const char* url_aemet = "http://www.aemet.es";
	char* comando;

	// Descargar pagina de busqueda del municipio
	comando = malloc(strlen(wget) + strlen(url_busqueda) + strlen(argv[1]) + 1 + 1);
	strcpy(comando, wget);
	strcat(comando, url_busqueda);
	strcat(comando, argv[1]);
	strcat(comando, "'");

	system(comando);

	// Abrir fichero descargado
	yyin = fopen("web-aemet", "r");
	if (yyin == NULL) {
		printf ("El fichero no se puede abrir\n");
		exit (-1);
	}

	// Analizar pagina descargada
	yylex();
	fclose(yyin);
	remove("web-aemet");

	if(!nmun) { // No se encuentra ningun municipio
		printf("No se encontraron resultados\n\n");
		exit(1);
	}
	else if(nmun > 1) { // Hay varias opciones
		// Menu para elegir resultado
		int elegido = elegir_resultado();

		// Descargar pagina del municipio escogido
		free(comando);
		comando = malloc(strlen(wget) + strlen(url_aemet) + strlen(urls[elegido]) + 1 + 1);
		strcpy(comando, wget);
		strcat(comando, url_aemet);
		strcat(comando, urls[elegido]);
		strcat(comando, "'");

		system(comando);

		// Abrir fichero descargado
		yyin = fopen("web-aemet", "r");
		if (yyin == NULL) {
			printf ("El fichero no se puede abrir\n");
			exit (-1);
		}

		// Analizar pagina descargada
		yylex();
		fclose(yyin);
		remove("web-aemet");
	}

	// Mostrar los resultados obtenidos
	reporte();


	// Liberar memoria
	free(comando);
	liberar_memoria();

	return 0;
}

// Copia el la cadena que contiene yytext en la direccion indicada (reserva memoria)
void copiar_yytext(char** destino) {
	*destino = malloc(strlen(yytext)+1);
	strcpy(*destino, yytext);
}

// Salida de los datos meteorologicos
void reporte () {
	int d, k;

	for(d=0, i=0; d<6; d++) {
		printf("***** %s *****\n", dias[d]);

		if(d==0) {
			for(k=0; k<4; k++, i++) {
				printf("%02i-%02ih:\t", k*6, k*6+6);
				printf("%sºC\t", temps[i]);
				printf("%s\n", cielos[i]);
				printf("\tProbabilidad de lluvia: %s\n", lluvias[i]);
			}

		}
		else if(d<3) {
			for(k=0; k<2; k++, i++) {
				printf("%02i-%02ih:\t", k*12, k*12+12);
				printf("%s\n", cielos[i]);
				printf("\tProbabilidad de lluvia: %s\n", lluvias[i]);
			}
		}
		else {
			printf("%s\n", cielos[i]);
			printf("Probabilidad de lluvia: %s\n", lluvias[i]);
			i++;
		}

		printf("Temperatura min/max: %s / %s\n", minimas[d], maximas[d]);

		printf("\n");
	}

}

// Menu para la eleccion entre varios posibles municipios
int elegir_resultado () {

	int elegido = -1;
	int i;
	int k;

	printf("Se encontraron %i resultados:\n", nmun);
	for(i=0; i<nmun; i++) {
		printf("%i) %s\n", i, nombres[i]);
	}

	printf("\nIntroduzca el municipio deseado (0-%i): ", nmun-1);

	do {
		k = scanf("%i", &elegido);
	} while(k!=1 || elegido<0 || elegido>=nmun);

	printf("\n");

	return elegido;
}

// Libera la memoria reservada durante la recopilacion de datos
void liberar_memoria () {
	for(i=0; i<NDIAS; i++) {
		free(dias[i]);
		free(minimas[i]);
		free(maximas[i]);
	}
	for(i=0; i<NHORAS; i++) {
		free(horas[i]);
	}
	for(i=0; i<NCIELOS; i++) {
		free(cielos[i]);
	}
	for(i=0; i<NTEMPS; i++) {
		free(temps[i]);
	}

	if(nmun>1) {
		for(i=0; i<nmun; i++) {
			free(nombres[i]);
			free(urls[i]);
		}
	}
}

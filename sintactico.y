%{
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <math.h>
#include <string.h>
#include "y.tab.h"
#include "ts.h"
#include "tercetos.h"
#include "validacion.h"

FILE  *yyin;
char *yytext;
%}

%union{
 char s[20];
}

%union{
 char i[20];
}

%token DEFVAR
%token ENDDEF

%token <s>ID
%token MAYOR MAYOR_IGUAL MENOR MENOR_IGUAL IGUAL DISTINTO   
%token ASIG SUMA RESTA MUL DIV
%token P_A P_C LL_A LL_C C_A C_C P_Y_C DP COMA

%token <i>ENTERO REAL CADENA INT FLOAT STRING

%token AND OR

%token IF ELSE WHILE AVG WRITE READ

%%
raiz:
    programa	{
				printf("Generando Tabla de Simbolos...\n");
				symbolTableToHtml(symbolTable,"ts.html");
				printf("Generando GCI\n");
				generarIntermedia();
				printf("->COMPILACION OK<-\n");
				}
	;

programa:
		sentencias
		;
sentencias:
			sentencias sent														{printf("GRUPO DE SENTENCIAS\n");}
			|sent																{printf("SENTENCIA INDIVIDUAL\n");}
			;								
sent:
    asignacion																	{printf("ASIGNACION\n");}
	|decision																	{printf("DECISION\n");}
	|declaracion																{printf("DECLARACION\n");}
	|iteracion																	{printf("ITERA\n");}
	|promedio																	{printf("AVG\n");}
	|entrada_salida																{printf("ENTRADA O SALIDA POR TECLADO\n");}
	;

	
asignacion:
			ID ASIG expresion
			{
				//printf("yytext:%s yyval.i:%s $:%s\n",yytext,yylval.i,$1);
				validarDefinicionVariable($1);
				symbol id = getSymbol($1);
				validarTipos(id.tipo);
				asigIndice = crear_terceto___(":=",$1,expIndice);
				printf("ASIGNACION SIMPLE\n");
			}
			|ID ASIG asignacion
			{
				//printf("@@@@yytext:%s yyval.i:%s $:%s\n",yytext,yylval.i,$1);
				validarDefinicionVariable($1);
				symbol id = getSymbol($1);
				validarTipos(id.tipo);
				asigIndice = crear_terceto___(":=",$1,expIndice);
				printf("ASIGNACION MULTIPLE\n");
			}
			;
			
decision:
        IF P_A condiciones P_C LL_A sentencias LL_C				    			{
																				modificarSalto(nroTerceto + 1, desapilar());
																				auxDesapilar = desapilar();
																				if(auxDesapilar == -1)
																					modificarSalto(nroTerceto + 1, desapilar());
																				else
																					apilar(auxDesapilar);
																				printf("IF\n");
																				}
		|IF P_A condiciones P_C LL_A sentencias LL_C ELSE						{
																				crear_terceto_("JI");
																				modificarSalto(nroTerceto + 1, desapilar());				
																				auxDesapilar = desapilar();
																				if(auxDesapilar == -1)
																					modificarSalto(nroTerceto + 1, desapilar());
																				else
																					apilar(auxDesapilar);
																				apilar(nroTerceto);
																				}
																				
				LL_A sentencias LL_C											{modificarSalto(nroTerceto + 1, desapilar());printf("IF-ELSE\n");}
		;
		
declaracion:
			DEFVAR declaraciones ENDDEF											{saveIdType();printf("BLOQUE DECLARACION\n");}
			;	
declaraciones:
				declaraciones formato_declaracion
				|formato_declaracion
				;
formato_declaracion:
					ID {validarPalabraReservada(yylval.s);}	DP tipo_dato		{validarLongitudId(yylval.s);saveId(yylval.s);printf("DECLARACION SIMPLE\n");}
					|ID COMA formato_declaracion								{validarLongitudId($1);symbol idTipo = getSymbol(yylval.s);saveId($1);saveType(idTipo.tipo);printf("DECLARACION MULTIPLE\n");}
					;
tipo_dato:
        INT																		{saveType("int");printf("INT\n");}
		|FLOAT																	{saveType("float");printf("FLOAT\n");}
		|STRING																	{saveType("string");printf("STRING\n");}
		;			
		
iteracion:
			WHILE P_A   
				{
				 apilar(nroTerceto+1);
				}
				condiciones P_C LL_A sentencias LL_C	
				{
					crear_terceto_("JI"); /*aca habria que desapilar para saber donde empezo la condicion para volver a ejecutarla*/
					modificarSalto(nroTerceto + 1,desapilar());//terceto de la condicion ante un falso
					auxDesapilar = desapilar();
					if(auxDesapilar == -1)
					{
					    modificarSalto(nroTerceto + 1, desapilar());
					}
					else
					{
					    apilar(auxDesapilar);
					}
					modificarSalto(desapilar(), nroTerceto); //salto incondicional al inicio del while
					printf("WHILE\n");
				}
			;

condiciones: 
            condicion 
                { 				
                condMulIndice = crear_terceto__(obtenerSalto(1), condMulIndice, nroTerceto);
                apilar(nroTerceto);
                }
            |condicion AND 
                {							
                crear_terceto__(obtenerSalto(1), condMulIndice, nroTerceto); //salto si es falso
                apilar(nroTerceto);
                apilar(-1); //para indicar que hubo and y tenemos que desapilar dos veces en algunos casos
                }
            condicion 					
                { 				
                crear_terceto__(obtenerSalto(1), condMulIndice, nroTerceto); //salto si es falso
                apilar(nroTerceto);
                }
            |condicion OR 
                {								
                crear_terceto__(obtenerSalto(0), condMulIndice, nroTerceto); //salto si es verdadero
                apilar(nroTerceto);
                }
            condicion 
                { 
                crear_terceto__(obtenerSalto(1), condMulIndice, nroTerceto); //salto si es falso
                modificarSalto(nroTerceto + 1, desapilar());
                apilar(nroTerceto);
                }
            |C_A condicion P_C
                { 
                condMulIndice = crear_terceto__(obtenerSalto(0), condMulIndice, nroTerceto);
                apilar(nroTerceto);
                }
            ;								

condicion: 
            expresion operador_comparacion
            {
				condIndice = expIndice;
            }
            expresion 
            {
				validarTipos("float");
                condMulIndice = crear_terceto__("CMP", condIndice, expIndice);
                printf("\nCONDICION"); 
            }
            ;

operador_comparacion:
                    IGUAL 
                    { 
                        operacionLogica = IGUAL;
                        printf("\nComparador: IGUAL\n"); 
                    }| 
                    MENOR 
                    { 
                        operacionLogica = MENOR;
                        printf("\nComparador: MENOR\n"); 
                    }| 
                    MAYOR 
                    { 
                        operacionLogica = MAYOR;
                        printf("\nComparador: MAYOR\n"); 
                    }| MAYOR_IGUAL
                    { 
                        operacionLogica = MAYOR_IGUAL;
                        printf("\nComparador: MAYOR_IGUAL\n"); 
                    }| 
                    MENOR_IGUAL
                    { 
                        operacionLogica = MENOR_IGUAL;
                        printf("\nComparador: MENOR_IGUAL\n"); 
                    }| 
                    DISTINTO 
                    { 
                        operacionLogica = DISTINTO;
                        printf("\nComparador: DISTINTO\n"); 
                    } 
				;								

promedio:
        AVG P_A C_A formato_promedio C_C P_C									{
																				char * valor;
																				sprintf(valor, "%.2f", cantAVG);
																				avgInd = crear_terceto_(valor);
																				crear_terceto___(":=","cantAVG",avgInd);
																				
																				int auxAvgInd = avgInd;
																				
																				sprintf(valor, "%d", contAVG);
																				avgInd = crear_terceto_(valor);
																				crear_terceto___(":=","contAVG",avgInd);
																				
																				crear_terceto__("/",auxAvgInd,avgInd);
																				
																				printf("FUNCION PROMEDIO (AVG) - RESULTADO: %.2f\n",(cantAVG/contAVG));
																				}
		;
		
formato_promedio:
                tipo_dato_promedio
					{
					cantAVG+=atof(yylval.i);
					contAVG++;
					//printf("yytext:%s yyval.i:%s cantAVG:%f contAVG:%d\n",yytext,yylval.i,cantAVG,contAVG);
					}
				|tipo_dato_promedio
					{
					cantAVG+=atof(yylval.i);
					contAVG++;
					//printf("-yytext:%s yyval.i:%s cantAVG:%f contAVG:%d\n",yytext,yylval.i,cantAVG,contAVG);
					}  COMA formato_promedio
				;
				
tipo_dato_promedio:
					ENTERO														{validarInt(yytext);printf("AVG-INT\n");}   
					|REAL														{validarFloat(yytext);printf("AVG-FLOAT\n");}
					;
				
entrada_salida:
				READ ID                                                         {printf("READ\n");}
                |WRITE ID                                                       {printf("WRITE\n");}
                ;
				
expresion:
        expresion RESTA termino											    	
		{
			validarTipos("float");
			expIndice = crear_terceto__("-", expIndice, terIndice);
			printf("RESTA\n");
		}
		|expresion SUMA termino
		{
			validarTipos("float");
			expIndice = crear_terceto__("+", expIndice, terIndice);
			printf("SUMA\n");
		}
		|termino																
		{
			//validarTipos("float");
			expIndice = terIndice;
			printf("TERMINO\n");
		}
		;									

termino:
        termino MUL factor														
		{
			validarTipos("float");
			terIndice = crear_terceto__("*", terIndice, facIndice);
			printf("MULTIPLICACION\n");
		}
		|termino DIV factor														
		{
			validarTipos("float");
			terIndice = crear_terceto__("/", terIndice, facIndice);
			printf("DIVISION\n");
		}
		|factor																	
		{
			//validarTipos("float");
			terIndice = facIndice;
			printf("FACTOR\n");
		}
		;									

factor:
        ID																		
		{
			symbol id = getSymbol(yylval.s);
			insertarTipo(id.tipo);
			facIndice = crear_terceto_(id.nombre);
			printf("ID\n");
		}
		|tipo																	{printf("CTE\n");}
		|P_A {terAuxIndice = terIndice; expAuxIndice = expIndice;} expresion P_C
			{ 
				facIndice = expIndice;
				terIndice = terAuxIndice;
				expIndice = expAuxIndice;
				printf("(EXPRESION)\n");
			} 
		;									

tipo:
    ENTERO																		
	{
		validarInt(yytext);
		/*
		symbol id = getSymbol(yylval.s);
		saveSymbol(id.valor,id.tipo,yytext);
		facIndice = crear_terceto_(id.nombre);
		*/
		facIndice = crear_terceto_(yytext);
		printf("INT\n");
	}   
	|REAL																		
	{
		validarFloat(yytext);
		/*
		symbol id = getSymbol(yylval.s);
		saveSymbol(id.valor,id.tipo,yytext);
		facIndice = crear_terceto_(id.valor);
		*/
		facIndice = crear_terceto_(yytext);
		printf("FLOAT\n");
	}
	|CADENA																		{validarString(yytext);printf("CADENA\n");}
	;

%%

int main(int argc,char *argv[])
{
  if ((yyin = fopen(argv[1], "rt")) == NULL)
  {
	printf("\nNo se puede abrir el archivo: %s\n", argv[1]);
  }
  else
  {
	yyparse();
  }
  
  fclose(yyin);
  return 0;
}

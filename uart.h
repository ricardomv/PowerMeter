#ifndef UART_H
#define UART_H

void initUART1(void);
void writeUART1(unsigned int data);
void writeStringUART1(const char * s);
int getCommandUART1(void);

#endif
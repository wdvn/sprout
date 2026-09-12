#ifndef CLAY_H
#define CLAY_H

typedef struct clay_node clay_node;

void clay_init(void);
clay_node* clay_node_new(void);
void clay_node_free(clay_node* node);

#endif // CLAY_H

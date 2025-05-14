# Importing nodes to ACM

These examples assumes that your agents exist in a namespace named `hardware-inventory`.

1. 
    ```
    sh import-nodes.sh -n hardware-inventory hardware-inventory <node1> <node2> ...
    ```

2.
    ```
    sh update-agents.sh -n hardware-inventory
    ```

3.
    ```
    sh attach-to-network.sh idle-agents-network <node1> <node2> ...
    ```

4.
    ```
    sh approve-agents.sh -n hardware-inventory
    ```


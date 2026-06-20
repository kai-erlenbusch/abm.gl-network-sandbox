# COMM-PDND

## WHAT IS IT?

The Communication-Based Model of Perceived Descriptive Norm Dynamics in Digital Networks (COMM-PDND) is an agent-based model specifically created to examine the dynamics of perceived descriptive norms in the context of digital network structures. The model, developed as part of a master's thesis titled "The Dynamics of Perceived Descriptive Norms in Digital Network Publics: An Agent-Based Simulation", emphasizes the critical role of communication processes in norm formation. It focuses on the role of communicative interactions in shaping these perceived descriptive norms.

The COMM-PDND model is tuned to explore the effects of normative deviance in digital social networks. It provides functionalities for manipulating agents according to their centrality positions within the network, and has a versatile set of customizable parameters, making it adaptable to a wide range of research contexts.

## HOW IT WORKS

The two central processes in the ABM are *norm signaling* and *norm inference*. Regarding the communicative process of norm formation and "the conceptual route of norm acquisisition" (Kashima et al., 2013), the dissemination of normative cues as well as the normative inference about the prevalence of a behavior are conceptualized as communicative actions (Friemel & Neuberger, 2021).

### Norm Signaling and Norm Inference as Communicative Actions 
#### The Production of Normative Messages (Norm Signaling)

The production of normative messages is based on the threshold model of "repeated activation in social networks" by Piedrahita et al. (2018), which takes into account both individual and social motivational factors.

- Individual motivation "omega" is modeled as a logarithmic function that continuously increases until the activation threshold is reached.

- Social motivation depends on the actions of neighboring agents and is represented by the constant parameter "epsilon", which is the signal intensity of activated agents.

As soon as the activation state exceeds the "activation-threshold", the agents send out a normative message based on their current perceived descriptive norm.

Initially, each agent is assigned a random activation state [0, 1]. Each activation results in a reset and brings the agents to the beginning of their activation cycle.

#### The Reception of Normative Messages (Norm Inference)

The reception of normative messages is conceived as a probability model based on the principle of selective exposure. The specific relevance of reception is calculated on the basis of the following parameters:

- Spatial component (distance): The constant "obj-distance" is used to pre-filter which messages are theoretically visible and receivable by the agents. In the initial configuration, the parameter is set to 2, so that only messages from proximal referents are considered.

- Social component (social cues): Messages that are frequently received in the local network have a higher probability of being received again. This leads to a positive feedback mechanism. The smaller "gamma" is set, the greater the influence of the reception frequency

- Temporal component (fatigue): The relevance of a message decreases over time, which reduces the probability of reception. When messages become irrelevant (average probability of reception < "obj-relevance"), they are removed from the system.

### Update: Descriptive Norm Perceptions

#### Hegselmann-Krause (HK) Model

The COMM-PDND uses an update mechanism to regularly adjust the descriptive norm perceptions of the agents. This mechanism is based on the HK model (Hegselmann & Krause, 2002), which is in the tradition of "similarity biased models of social influence". According to this model, the strength of social influence between connected individuals is directly related to their similarity. In terms of individual changes in descriptive norm perception, this means:

- At each time step, agents adjust their own descriptive norm perception by taking into account the average of all normative information received during that simulation step.

- Each agent has an determined bounded confidence level ("fix-bc-level"), which indicates the tolerance for divergent normative information. Only information that deviates less than the bc-level from one's norm perception is considered.

For the concrete implementation of the mechanism, the NetLogo model of Lorenz (2012) was used as a guideline.

### Noise

The "noise" parameter is designed to account for random deviations in the agents' descriptive norm perception at each simulation step (Flache et al., 2017, para. 2.44). It helps to account for unpredictable changes in norm perception that cannot be explained by communicative interactions in the network.

To regulate the variances, the "noise-rate" is kept relatively low in the initial configuration (*p* = 0.02). The random deviations follow a normal distribution with a "noise-range" of *SD* = 0.2.

### Stubbornness

The parameter "stubbornness" serves as a kind of resistance mechanism that limits the adaptability of agents' descriptive norm perceptions (Deffuant, 2002). The core idea behind this parameter is that there are agents who are so entrenched in their perceptions that they not willing or able to change them in response to social influence.

The "extremism_type" parameter can be used to choose between "one-sided" or "two-sided" stubbornness. The "extremism_range" parameter determines the range of norm perceptions in which agents maintain their descriptive norm perceptions despite external influences.

Example: extremism_type:two-sided; extremism_range: 0.02
Here, agents whose current descriptive norm perception is either at the lower (near 0) or upper (near 1) end of the norm perception range [0, 1] are in the "extremism zone". This setting could represent an asymmetric interaction dynamic in which agents with extremely pronounced low or high descriptive norm perceptions are more likely to influence others with their normative information than to be influenced by others themselves. 

## HOW TO USE IT

#### 1. SETUP

- Generate a social network with undirected connections based on the number of agents and the network topology selection.

- Make sure to set the "norm-perception-distribution" and the "fix-bc-level" as desired before pressing SETUP.

Note: A high number of agents can extremely slow down the ABM.

#### 2. LAYOUT

- Layout the agents in the network either as "circle" or as "spring" to increase the visibility of the network and possible clusters. 

- Additionally, LABELS can be turned on and off to show the exact current norm perception. 

#### 3. GO

- Click on GO to start the simulation. Click on GO ONCE to simulate only one simulation step.

#### 4. HIGHLIGHTING

- In addition to colouring the norm perceptions by clicking on COLOURIZE, the size of the agents can be displayed in relation to their norm perceptions by clicking on RESIZE (the same applies to messages).

- When SHOW CENTRALITY is clicked, the centrality measures of the agents are visualised by their size and colour, allowing immediate comparison.

- Furthermore, the generated network can be described in more detail by displaying the communities and cliques (to see the effect of "maximal cliques" you have to move the cursor over the agents).

## THINGS TO TRY

#### [OPTIONAL] SIMULATING DEVIANCE

You can select a number of "nb-selection" agents based on their network position (peripheral vs. central) and assign them a specific norm perception and their own bc-level based on the beta distribution of the "deviant-norm-perception". 

This mechanism can be used to implement the scenario of normative deviance in the system.

The network position (peripheral vs. central) is based on the selection of the "centrality-measure". Make sure that before clicking on "selection", the "subject-labels?" is set to "on" to calculate the centrality correctly. 

- If "network-position" is set to "central", this means that the agents will be sorted in descending order of their centrality value and the first "nb-selection" will be selected as agents to be manipulated.

- If "network-position" is set to "peripheral", this means that the agents will be sorted in ascending order of their centrality value and the first "nb-selection" are selected as agents to be manipulated.

Click on "SELECT DEVIANTS" to make visible which agents would be manipulated (red).

Click on "MANIPULATE" to execute the manipulation. 

**Example of Application**.

In the master thesis, a 2x2 simulation experiment was conducted by systematically varying the parameters "network-position" and "deviant-bc-level" to investigate the influence of deviant agents on the dynamics of descriptive norm perceptions.


## REFERENCES

**Deffuant, G., Amblard, F., Weisbuch, G., & Faure, T. (2002).** How can extremism prevail? A study based on the relative agreement interaction model. *Journal of artificial societies and social simulation*, *5*(4). https://www.jasss.org/5/4/1.html 

**Flache, A., Mäs, M., Feliciani, T., Chattoe-Brown, E., Deffuant, G., Huet, S., & Lorenz, J. (2017).** Models of Social Influence: Towards the Next Frontiers. *Journal of Artificial Societies and Social Simulation*, *20*(4), 2. https://doi.org/10.18564/jasss.3521

**Friemel, T. N., & Neuberger, C. (2021).** Öffentlichkeit als dynamisches Netzwerk. In M. Eisenegger, M. Prinzing, P. Ettinger, & R. Blum (Hrsg.), *Digitaler Strukturwandel der Öffentlichkeit* (S. 81–96). Springer Fachmedien Wiesbaden. https://doi.org/10.1007/978-3-658-32133-8_5

**Hegselmann, R. & Krause, U. (2002).** Opinion Dynamics and Bounded Confidence, Models, Analysis and Simulation. *Journal of Artificial Societies and Social Simulation*, *5*, 2. https://www.jasss.org/5/3/2.html

**Lorenz, J. (2012).** Continuous Opinion Dynamics under Bounded Confidence. *NetLogo*. http://ccl.northwestern.edu/netlogo/models/community/bc

**Piedrahita, P., Borge-Holthoefer, J., Moreno, Y., & González-Bailón, S. (2018).** The contagion effects of repeated activation in social networks. *Social Networks*, 54, 326–335. https://doi.org/10.1016/j.socnet.2017.11.001

## CREDITS

COMM-PDND © 2023 by Lars Reinelt is licensed under CC BY-NC-SA 4.0 

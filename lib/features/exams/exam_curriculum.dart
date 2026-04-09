class CurriculumTopicGroup {
  final String title;
  final List<String> subtopics;

  const CurriculumTopicGroup({
    required this.title,
    this.subtopics = const <String>[],
  });
}

class CurriculumSection {
  final String id;
  final String title;
  final List<String> topics;
  final List<CurriculumTopicGroup> topicGroups;

  const CurriculumSection({
    required this.id,
    required this.title,
    required this.topics,
    this.topicGroups = const <CurriculumTopicGroup>[],
  });
}

class CurriculumPaper {
  final String id;
  final String title;
  final int durationMinutes;
  final int marks;
  final List<String> sectionIds;
  final List<String> tiers;
  final int? weightPercent;

  const CurriculumPaper({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.marks,
    required this.sectionIds,
    this.tiers = const <String>[],
    this.weightPercent,
  });
}

class SubjectCurriculum {
  final String subject;
  final List<CurriculumSection> sections;
  final List<CurriculumPaper> papers;

  const SubjectCurriculum({
    required this.subject,
    required this.sections,
    required this.papers,
  });
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll('&', 'and');
}

const Map<String, SubjectCurriculum> _gcseCurriculum = {
  'mathematics': SubjectCurriculum(
    subject: 'Mathematics',
    sections: [
      CurriculumSection(
        id: 'number',
        title: '1. Number and Arithmetic',
        topics: [
          'integers and place value',
          'factors and multiples',
          'prime factors and indices',
          'fractions',
          'decimals',
          'percentages',
          'ratio and proportion',
          'direct and inverse proportion',
          'bounds and standard form',
          'surds',
          'recurring decimals',
          'financial mathematics',
        ],
      ),
      CurriculumSection(
        id: 'algebra',
        title: '2. Algebra and Functions',
        topics: [
          'substitution',
          'expanding and factorising',
          'algebraic fractions',
          'equations',
          'simultaneous equations',
          'quadratic equations',
          'inequalities',
          'sequences',
          'nth term',
          'graphs of linear and quadratic functions',
          'graphs of cubic and reciprocal functions',
          'real-life graphs',
          'iterative methods',
        ],
      ),
      CurriculumSection(
        id: 'geometry',
        title: '3. Geometry and Measures',
        topics: [
          'angle facts',
          'parallel lines',
          'polygons',
          'circle theorems',
          'construction and loci',
          'bearings',
          'congruence and similarity',
          'pythagoras theorem',
          'trigonometry',
          'sine and cosine rules',
          'area and perimeter',
          'surface area and volume',
          'transformations',
          'vectors',
        ],
      ),
      CurriculumSection(
        id: 'stats_prob',
        title: '4. Statistics and Probability',
        topics: [
          'collecting data',
          'sampling methods',
          'frequency tables',
          'charts and histograms',
          'averages',
          'range and interquartile range',
          'cumulative frequency',
          'box plots',
          'scatter graphs and correlation',
          'time series',
          'probability scales',
          'relative frequency',
          'probability trees',
          'venn diagrams',
          'conditional probability',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Non-Calculator)',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['number', 'algebra', 'geometry'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Calculator)',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['algebra', 'geometry', 'stats_prob'],
      ),
      CurriculumPaper(
        id: 'paper_3',
        title: 'Paper 3 (Calculator)',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['number', 'algebra', 'stats_prob'],
      ),
    ],
  ),
  'english language': SubjectCurriculum(
    subject: 'English Language',
    sections: [
      CurriculumSection(
        id: 'reading_nonfiction',
        title: '1. Reading Non-Fiction and Comparative Reading',
        topics: [
          'retrieval and selection of evidence',
          'summary writing',
          'inference from explicit and implicit meanings',
          'analysis of language methods',
          'analysis of structure in non-fiction',
          'writer viewpoint and perspective',
          'comparison of ideas and attitudes',
          'comparison of methods',
          'evaluation of statements',
          'critical judgement with textual support',
          'synthesis across sources',
          'timed source navigation',
        ],
      ),
      CurriculumSection(
        id: 'reading_fiction',
        title: '2. Reading Fiction',
        topics: [
          'narrative voice and perspective',
          'characterisation',
          'setting and atmosphere',
          'plot development',
          'structural shifts and turning points',
          'language analysis with terminology',
          'effect on reader',
          'evaluating narrative choices',
          'close analysis of extracts',
          'selecting high-value quotations',
          'narrative voice',
          'structure',
          'characterisation',
          'effect on reader',
        ],
      ),
      CurriculumSection(
        id: 'writing',
        title: '3. Writing Craft and Technical Accuracy',
        topics: [
          'descriptive writing',
          'narrative writing',
          'transactional writing',
          'persuasive writing',
          'argument and counter-argument',
          'tone and register',
          'audience and purpose',
          'cohesion and paragraphing',
          'sentence variety',
          'vocabulary control',
          'spelling punctuation and grammar',
          'editing and proofreading',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Creative Reading and Writing)',
        durationMinutes: 105,
        marks: 80,
        sectionIds: ['reading_fiction', 'writing'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Writers Viewpoints and Perspectives)',
        durationMinutes: 105,
        marks: 80,
        sectionIds: ['reading_nonfiction', 'writing'],
      ),
    ],
  ),
  'english literature': SubjectCurriculum(
    subject: 'English Literature',
    sections: [
      CurriculumSection(
        id: 'shakespeare',
        title: '1. Shakespeare',
        topics: [
          'plot and dramatic structure',
          'major themes',
          'character arcs',
          'quotation learning strategy',
          'language and imagery',
          'dramatic methods',
          'context and audience response',
          'single extract analysis',
          'whole-text references',
          'balanced argument writing',
        ],
      ),
      CurriculumSection(
        id: '19th_novel',
        title: '2. 19th-Century Novel',
        topics: [
          'plot progression',
          'social and historical context',
          'narrative perspective',
          'character relationships',
          'writer methods',
          'quotation tracking',
          'interpretive debate',
          'extract to whole-text linkage',
          'analysis of setting and symbolism',
          'comparative interpretation',
        ],
      ),
      CurriculumSection(
        id: 'poetry',
        title: '3. Poetry Anthology and Unseen Poetry',
        topics: [
          'poetic form',
          'meter and rhythm',
          'imagery and figurative language',
          'tone and voice',
          'structural shifts in poems',
          'theme comparison',
          'method comparison',
          'unseen poetry first response',
          'unseen comparison strategy',
          'embedding quotations in poetry essays',
        ],
      ),
      CurriculumSection(
        id: 'modern_text',
        title: '4. Modern Text',
        topics: [
          'central themes',
          'character arcs',
          'key scenes and turning points',
          'dramatic or narrative methods',
          'contextual framing',
          'critical interpretations',
          'evaluative writing',
          'synoptic essay planning',
          'high-value quotations',
          'conclusion quality',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Shakespeare and 19th-Century Novel)',
        durationMinutes: 105,
        marks: 64,
        sectionIds: ['shakespeare', '19th_novel'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Modern Text and Poetry)',
        durationMinutes: 135,
        marks: 96,
        sectionIds: ['modern_text', 'poetry'],
      ),
    ],
  ),
  'combined science': SubjectCurriculum(
    subject: 'Combined Science',
    sections: [
      CurriculumSection(
        id: 'bio_paper_1_topics',
        title: 'Biology Paper 1 Topics',
        topics: [
          'B1.1 Cell structure',
          'B1.2 Cell division',
          'B1.3 Transport in cells',
          'B1 required practicals: microscopy and food tests',
          'B2.1 Organisation in animals',
          'B2.2 Organisation in plants',
          'B3.1 Communicable diseases',
          'B3.2 Human defence systems',
          'B3.3 Vaccination antibiotics and drug development',
          'B4.1 Photosynthesis',
          'B4.2 Respiration',
          'B4 required practical: rate of photosynthesis',
        ],
      ),
      CurriculumSection(
        id: 'bio_paper_2_topics',
        title: 'Biology Paper 2 Topics',
        topics: [
          'B5.1 Homeostasis and the nervous system',
          'B5.2 Hormonal coordination and control',
          'B5.3 Human endocrine and reproductive hormones',
          'B6.1 Reproduction',
          'B6.2 Variation and evolution',
          'B6.3 The development of understanding of genetics and evolution',
          'B6.4 Classification of living organisms',
          'B7.1 Adaptations interdependence and competition',
          'B7.2 Organisation of an ecosystem',
          'B7.3 Biodiversity and ecosystems',
          'B7 required practicals: ecology sampling',
        ],
      ),
      CurriculumSection(
        id: 'chem_paper_1_topics',
        title: 'Chemistry Paper 1 Topics',
        topics: [
          'C1 Atomic structure and the periodic table',
          'C2 Bonding structure and properties of matter',
          'C3 Quantitative chemistry',
          'C4 Chemical changes',
          'C5 Energy changes',
          'C1-C5 required practicals',
          'electrolysis and extraction of metals',
          'acids alkalis and neutralisation calculations',
          'moles concentration and gas volume calculations',
        ],
      ),
      CurriculumSection(
        id: 'chem_paper_2_topics',
        title: 'Chemistry Paper 2 Topics',
        topics: [
          'C6 Rate and extent of chemical change',
          'C7 Organic chemistry',
          'C8 Chemical analysis',
          'C9 Chemistry of the atmosphere',
          'C10 Using resources',
          'C6-C10 required practicals',
          'reversible reactions and equilibrium',
          'instrumental methods and chromatographic analysis',
          'life cycle assessment and sustainability',
        ],
      ),
      CurriculumSection(
        id: 'phys_paper_1_topics',
        title: 'Physics Paper 1 Topics',
        topics: [
          'P1 Energy',
          'P2 Electricity',
          'P3 Particle model of matter',
          'P4 Atomic structure',
          'P1-P4 required practicals',
          'energy transfers and efficiency calculations',
          'series and parallel circuit analysis',
          'radioactivity half-life and nuclear equations',
          'specific heat capacity and density calculations',
        ],
      ),
      CurriculumSection(
        id: 'phys_paper_2_topics',
        title: 'Physics Paper 2 Topics',
        topics: [
          'P5 Forces',
          'P6 Waves',
          'P7 Magnetism and electromagnetism',
          'P8 Space physics',
          'P5-P7 required practicals',
          'motion graphs and SUVAT calculations',
          'electromagnetic spectrum applications',
          'motor effect generator effect and transformers',
          'solar system and life cycle of stars',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'bio_paper_1',
        title: 'Biology Paper 1',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['bio_paper_1_topics'],
      ),
      CurriculumPaper(
        id: 'bio_paper_2',
        title: 'Biology Paper 2',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['bio_paper_2_topics'],
      ),
      CurriculumPaper(
        id: 'chem_paper_1',
        title: 'Chemistry Paper 1',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['chem_paper_1_topics'],
      ),
      CurriculumPaper(
        id: 'chem_paper_2',
        title: 'Chemistry Paper 2',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['chem_paper_2_topics'],
      ),
      CurriculumPaper(
        id: 'phys_paper_1',
        title: 'Physics Paper 1',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['phys_paper_1_topics'],
      ),
      CurriculumPaper(
        id: 'phys_paper_2',
        title: 'Physics Paper 2',
        durationMinutes: 75,
        marks: 70,
        sectionIds: ['phys_paper_2_topics'],
      ),
    ],
  ),
  'biology': SubjectCurriculum(
    subject: 'Biology',
    sections: [
      CurriculumSection(
        id: 'key_concepts',
        title: '1. Key Concepts in Biology',
        topics: [
          'eukaryotic organisms',
          'prokaryotic organisms',
          'specialised cells',
          'microscopy',
          'using units',
          'the action of enzymes',
          'factors affecting enzymes',
          'practical: enzymes and pH',
          'rate calculations for enzyme activity',
          'enzymes as biological catalysts',
          'practical: food tests',
          'practical: energy content in food',
          'diffusion',
          'osmosis',
          'active transport',
        ],
      ),
      CurriculumSection(
        id: 'cells_control',
        title: '2. Cells and Control',
        topics: [
          'mitosis',
          'uncontrolled cell division',
          'growth',
          'the importance of cell differentiation',
          'animal stem cells',
          'plant stem cells',
          'stem cells in medicine',
          'the brain',
          'scanning the brain',
          'the human nervous system',
          'synapses',
          'simple reflex arc',
          'the human eye',
          'defects of the eye',
        ],
      ),
      CurriculumSection(
        id: 'genetics',
        title: '3. Genetics',
        topics: [
          'types of reproduction',
          'the role of meiosis',
          'DNA and the genome',
          'protein synthesis',
          'genetic variants',
          'mendel work',
          'key definitions',
          'predicting genetic inheritance',
          'inheritance of sex',
          'codominance',
          'sex-linked characteristics',
          'polygenic inheritance',
          'variation',
          'mutations',
        ],
      ),
      CurriculumSection(
        id: 'natural_selection_and_modification',
        title: '4. Natural Selection and Genetic Modification',
        topics: [
          'the work of darwin and wallace',
          'evolution by natural selection',
          'evidence of evolution',
          'the pentadactyl limb',
          'the three domains',
          'selective breeding',
          'tissue cultures',
          'genetic engineering',
          'the process of genetic engineering',
          'meeting global food demands',
          'evaluating genetic engineering',
          'the human genome project',
        ],
      ),
      CurriculumSection(
        id: 'health_disease_medicine',
        title: '5. Health, Disease and Development of Medicines',
        topics: [
          'health and disease',
          'pathogens',
          'common infections',
          'plant defence responses',
          'plant diseases',
          'human defence responses',
          'immunity',
          'vaccination',
          'antibiotics',
          'investigating microorganisms',
          'practical: effects of antiseptics and antibiotics',
          'discovery and development of new drugs',
          'monoclonal antibodies',
          'lifestyle and non-communicable disease',
          'cardiovascular disease',
        ],
      ),
      CurriculumSection(
        id: 'plant_structures',
        title: '6. Plant Structures and Their Functions',
        topics: [
          'photosynthesis',
          'limiting factors',
          'light and rate of photosynthesis',
          'practical: light and photosynthesis',
          'root hair cells',
          'xylem and phloem',
          'structure of the leaf',
          'living in extreme conditions',
          'transport of water and mineral ions',
          'factors affecting water uptake',
          'translocation',
          'plant hormones and growth',
          'using plant hormones commercially',
        ],
      ),
      CurriculumSection(
        id: 'animal_coordination_homeostasis',
        title: '7. Animal Coordination, Control and Homeostasis',
        topics: [
          'the endocrine system',
          'adrenaline',
          'thyroxine',
          'hormones and menstrual cycle',
          'contraception',
          'hormones and assisted reproductive technology',
          'importance of homeostasis',
          'thermoregulation',
          'vasoconstriction and vasodilation',
          'osmoregulation',
          'forming urine',
          'ADH',
          'kidney failure',
          'formation of urea',
          'regulating blood glucose concentration',
          'diabetes',
        ],
      ),
      CurriculumSection(
        id: 'exchange_transport_animals',
        title: '8. Exchange and Transport in Animals',
        topics: [
          'need for exchange surfaces in multicellular organisms',
          'factors affecting rate of diffusion',
          'human gas exchange system structure',
          'adaptations of alveoli for gas exchange',
          'ventilation and breathing mechanics',
          'aerobic and anaerobic respiration in humans',
          'oxygen debt and recovery after exercise',
          'blood components and their functions',
          'blood vessels: arteries veins capillaries',
          'double circulatory system and heart function',
          'coronary heart disease and treatment strategies',
          'transpiration stream and mass flow in plants',
          'xylem and phloem transport pathways',
          'required practical: investigate effect of exercise on breathing rate',
        ],
      ),
      CurriculumSection(
        id: 'ecosystems_material_cycles',
        title: '9. Ecosystems and Material Cycles',
        topics: [
          'key terms in ecology',
          'abiotic and biotic factors',
          'interdependence',
          'parasitism and mutualism',
          'biodiversity',
          'sampling organisms',
          'trophic levels and food chains',
          'food webs',
          'food pyramids',
          'transfer of energy',
          'the water cycle',
          'the carbon cycle',
          'the nitrogen cycle',
          'decomposition and decay',
          'human impact on biodiversity',
          'assessing pollution',
          'benefits of maintaining biodiversity',
          'food security',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'key_concepts',
          'cells_control',
          'genetics',
          'health_disease_medicine',
          'plant_structures',
        ],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'natural_selection_and_modification',
          'animal_coordination_homeostasis',
          'exchange_transport_animals',
          'ecosystems_material_cycles',
          'genetics',
        ],
      ),
    ],
  ),
  'chemistry': SubjectCurriculum(
    subject: 'Chemistry',
    sections: [
      CurriculumSection(
        id: 'atomic_and_periodic',
        title: '1. Atomic Structure and the Periodic Table',
        topics: [
          'the atom',
          'mass number and atomic number',
          'electronic structure',
          'history of the atom',
          'isotopes',
          'development of periodic table',
          'groups and periods',
          'group 1 alkali metals',
          'group 7 halogens',
          'group 0 noble gases',
          'transition metals',
        ],
      ),
      CurriculumSection(
        id: 'bonding_structure_properties',
        title: '2. Bonding, Structure and Properties of Matter',
        topics: [
          'ionic bonding',
          'covalent bonding',
          'metallic bonding',
          'simple molecular substances',
          'giant ionic lattices',
          'giant covalent structures',
          'polymers',
          'nanoparticles',
          'states of matter',
          'changing state',
          'separation techniques',
          'practical: chromatography',
        ],
      ),
      CurriculumSection(
        id: 'quantitative_chemistry',
        title: '3. Quantitative Chemistry',
        topics: [
          'relative formula mass',
          'moles',
          'amount of substance calculations',
          'chemical equations',
          'concentration calculations',
          'atom economy',
          'percentage yield',
          'gas volumes',
          'practical: titration',
        ],
      ),
      CurriculumSection(
        id: 'chemical_changes',
        title: '4. Chemical Changes',
        topics: [
          'reactivity series',
          'oxidation and reduction',
          'electrolysis',
          'extracting metals',
          'acids and alkalis',
          'salt preparation',
          'neutralisation',
          'electrochemical cells',
          'practical: electrolysis',
        ],
      ),
      CurriculumSection(
        id: 'energy_changes',
        title: '5. Energy Changes',
        topics: [
          'exothermic and endothermic reactions',
          'energy transfers in chemical reactions',
          'reaction profiles',
          'activation energy',
          'bond energies',
          'calculating energy changes from bond energies',
          'cells and batteries',
          'fuel cells',
          'advantages and limitations of fuel cells',
          'energy changes and sustainability',
          'practical: temperature changes',
        ],
      ),
      CurriculumSection(
        id: 'rates_equilibrium',
        title: '6. Rate and Extent of Chemical Change',
        topics: [
          'rate of reaction',
          'collision theory',
          'factors affecting rate',
          'surface area and particle size effects',
          'concentration and pressure effects',
          'catalysts and activation energy',
          'measuring rate of reaction methods',
          'reversible reactions',
          'dynamic equilibrium',
          'Le Chatelier principle',
          'industrial process conditions and compromise',
          'practical: rates',
        ],
      ),
      CurriculumSection(
        id: 'organic_chemistry',
        title: '7. Organic Chemistry',
        topics: [
          'crude oil and fuels',
          'fractional distillation',
          'alkanes',
          'alkenes',
          'cracking',
          'alcohols',
          'carboxylic acids',
          'esters',
          'addition polymerisation',
          'condensation polymerisation',
        ],
      ),
      CurriculumSection(
        id: 'chemical_analysis',
        title: '8. Chemical Analysis',
        topics: [
          'pure substances',
          'formulations',
          'chromatography',
          'interpreting chromatograms and Rf values',
          'gas tests',
          'flame tests',
          'tests for ions',
          'instrumental methods',
          'mass spectrometry overview',
          'required practical: chromatography separation',
          'required practical: tests for positive and negative ions',
        ],
      ),
      CurriculumSection(
        id: 'atmosphere_resources',
        title: '9. Chemistry of the Atmosphere and Using Resources',
        topics: [
          'earth early atmosphere',
          'greenhouse gases',
          'global climate change',
          'atmospheric pollutants',
          'potable water',
          'wastewater treatment',
          'life cycle assessment',
          'reduce reuse recycle',
          'corrosion',
          'alloys and composites',
          'fertilisers',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'atomic_and_periodic',
          'bonding_structure_properties',
          'quantitative_chemistry',
          'chemical_changes',
          'energy_changes',
        ],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'rates_equilibrium',
          'organic_chemistry',
          'chemical_analysis',
          'atmosphere_resources',
        ],
      ),
    ],
  ),
  'physics': SubjectCurriculum(
    subject: 'Physics',
    sections: [
      CurriculumSection(
        id: 'energy_transfers',
        title: '1. Energy',
        topics: [
          'energy stores and pathways',
          'conservation of energy',
          'work done',
          'power',
          'efficiency',
          'national and global energy resources',
          'specific heat capacity',
          'insulation and payback',
          'practical: thermal insulation',
        ],
      ),
      CurriculumSection(
        id: 'electricity',
        title: '2. Electricity',
        topics: [
          'charges and current',
          'potential difference',
          'resistance',
          'series and parallel circuits',
          'electrical power',
          'domestic electricity',
          'mains electricity',
          'static electricity',
          'practical: resistance',
        ],
      ),
      CurriculumSection(
        id: 'waves',
        title: '3. Waves',
        topics: [
          'wave properties',
          'transverse and longitudinal waves',
          'reflection and refraction',
          'lenses and magnification',
          'electromagnetic spectrum',
          'ultrasound',
          'seismic waves',
          'black body radiation',
        ],
      ),
      CurriculumSection(
        id: 'particles',
        title: '4. Particle Model of Matter',
        topics: [
          'density',
          'states of matter and particle arrangement',
          'changes of state',
          'specific latent heat',
          'internal energy',
          'gas pressure and temperature',
          'particle motion and pressure relationships',
          'work done on a gas',
          'practical: density',
        ],
      ),
      CurriculumSection(
        id: 'atomic_physics',
        title: '5. Atomic Structure',
        topics: [
          'atoms and isotopes',
          'radioactive decay',
          'nuclear equations',
          'half-life',
          'uses of radiation in medicine and industry',
          'radiation hazards',
          'background radiation',
          'contamination and irradiation',
          'nuclear fission and fusion',
          'nuclear waste and safety considerations',
        ],
      ),
      CurriculumSection(
        id: 'forces',
        title: '6. Forces',
        topics: [
          'scalars and vectors',
          'speed and velocity',
          'acceleration',
          'newton laws',
          'stopping distance',
          'momentum',
          'moments and levers',
          'pressure',
          'elasticity and springs',
          'practical: acceleration',
        ],
      ),
      CurriculumSection(
        id: 'magnetism_electromagnetism',
        title: '7. Magnetism and Electromagnetism',
        topics: [
          'permanent and induced magnets',
          'magnetic fields',
          'electromagnets',
          'motor effect',
          'loudspeakers',
          'electric motors',
          'generators',
          'transformers',
        ],
      ),
      CurriculumSection(
        id: 'space_physics',
        title: '8. Space Physics',
        topics: [
          'solar system',
          'orbits and gravitational attraction',
          'life cycle of stars',
          'main sequence protostar and red giant stages',
          'white dwarfs neutron stars and black holes',
          'orbital motion',
          'red shift',
          'big bang theory',
          'evidence for the expanding universe',
          'satellites',
          'natural and artificial satellites',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'energy_transfers',
          'electricity',
          'particles',
          'atomic_physics',
        ],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2',
        durationMinutes: 105,
        marks: 100,
        sectionIds: [
          'forces',
          'waves',
          'magnetism_electromagnetism',
          'space_physics',
        ],
      ),
    ],
  ),
  'history': SubjectCurriculum(
    subject: 'History',
    sections: [
      CurriculumSection(
        id: 'period_study',
        title: '1. Period Study',
        topics: [
          'option: Germany 1890-1945: Democracy and dictatorship',
          'option: Conflict and tension 1918-1939',
          'option: Conflict and tension between East and West 1945-1972',
          'option: America 1920-1973: Opportunity and inequality',
          'option: Russia 1894-1945: Tsardom and communism',
          'causation consequence change and continuity',
          'chronology and periodisation',
          'significance and turning points',
          'using specific contextual evidence',
          'supported historical judgements',
        ],
      ),
      CurriculumSection(
        id: 'depth_study',
        title: '2. Depth Study',
        topics: [
          'option: Norman England c1066-c1100',
          'option: Medieval England c1250-c1500',
          'option: Elizabethan England c1568-1603',
          'option: Restoration England 1660-1685',
          'option: Britain: Health and the people c1000-present',
          'option: Britain: Power and the people c1170-present',
          'option: Britain: Migration empires and the people c790-present',
          'source utility provenance and inference',
          'interpretations comparison and evaluation',
          'narrative account structure and precision',
          'balanced argument with own knowledge',
        ],
      ),
      CurriculumSection(
        id: 'british',
        title: '3. British Thematic Study',
        topics: [
          'historic environment source questions',
          'linking site evidence to wider period',
          'theme over long duration',
          'continuity and change over time',
          'second-order concepts in thematic essays',
          'evaluative judgement and substantiation',
          'exam technique by question type',
          'timing and planning high-mark answers',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Thematic + Historic Environment)',
        durationMinutes: 120,
        marks: 52,
        sectionIds: ['british', 'period_study'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Period + British Depth)',
        durationMinutes: 120,
        marks: 64,
        sectionIds: ['period_study', 'depth_study'],
      ),
    ],
  ),
  'geography': SubjectCurriculum(
    subject: 'Geography',
    sections: [
      CurriculumSection(
        id: 'physical',
        title: '1. Physical Geography',
        topics: [
          '3.1.1 The challenge of natural hazards',
          '3.1.2 The living world',
          '3.1.3 Physical landscapes in the UK',
          'coastal landscapes and processes',
          'river landscapes and processes',
          'weather climate and climate change',
          'ecosystems and biomes',
          'tropical rainforests and hot deserts',
          'tectonic and atmospheric hazards',
          'physical geography case studies',
        ],
      ),
      CurriculumSection(
        id: 'human',
        title: '2. Human Geography',
        topics: [
          '3.2.1 Urban issues and challenges',
          '3.2.2 The changing economic world',
          '3.2.3 The challenge of resource management',
          'development indicators and reducing the development gap',
          'globalisation and changing UK economy',
          'sustainable urban living',
          'food water and energy resources',
          'human geography case studies',
          'tourism regeneration and inequality',
        ],
      ),
      CurriculumSection(
        id: 'skills',
        title: '3. Fieldwork and Geographical Skills',
        topics: [
          '3.3 Geographical applications',
          '3.4 Geographical skills',
          'fieldwork planning and enquiry process',
          'primary and secondary data collection',
          'sampling and risk assessment',
          'cartographic graphical and numerical skills',
          'statistical analysis and interpretation',
          'conclusions evaluation and critique',
          'issue evaluation and decision making',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Living with Physical Environment)',
        durationMinutes: 90,
        marks: 88,
        sectionIds: ['physical'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Challenges in the Human Environment)',
        durationMinutes: 90,
        marks: 88,
        sectionIds: ['human'],
      ),
      CurriculumPaper(
        id: 'paper_3',
        title: 'Paper 3 (Geographical Applications)',
        durationMinutes: 75,
        marks: 76,
        sectionIds: ['skills'],
      ),
    ],
  ),
  'computer science': SubjectCurriculum(
    subject: 'Computer Science',
    sections: [
      CurriculumSection(
        id: 'systems',
        title: '1. Computer Systems',
        topics: [
          '3.3 Fundamentals of data representation',
          '3.4 Computer systems',
          '3.5 Computer networks',
          '3.6 Cyber security',
          'CPU architecture and performance',
          'memory storage and embedded systems',
          'network protocols topologies and layers',
          'types of cyber attack and prevention',
          'systems software and utility software',
          'ethical legal cultural and environmental issues',
        ],
      ),
      CurriculumSection(
        id: 'algorithms',
        title: '2. Algorithms and Programming',
        topics: [
          '3.1 Fundamentals of algorithms',
          '3.2 Programming',
          'algorithm design and decomposition',
          'pseudocode flowcharts and trace tables',
          'sequence selection iteration',
          'procedures functions arrays and files',
          'searching and sorting algorithms',
          'computational thinking and abstraction',
          'test plans debugging and robustness',
          'writing maintainable program code',
        ],
      ),
      CurriculumSection(
        id: 'data',
        title: '3. Data Representation',
        topics: [
          'binary denary and hexadecimal conversion',
          'binary addition and binary shifts',
          'character sets and encoding',
          'images colour depth and metadata',
          'sound sampling bit rate and file size',
          'compression methods and trade-offs',
          'logic gates truth tables and Boolean logic',
          'SQL and relational databases',
          'data structures in problem solving',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Computer Systems)',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['systems', 'data'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Computational Thinking)',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['algorithms'],
      ),
    ],
  ),
  'business': SubjectCurriculum(
    subject: 'Business',
    sections: [
      CurriculumSection(
        id: 'business_activity',
        title: '1. Business in the Real World',
        topics: [
          '3.1.1 The purpose and nature of business',
          '3.1.2 Business ownership',
          '3.1.3 Setting business aims and objectives',
          '3.1.4 Stakeholders',
          '3.1.5 Business location',
          '3.1.6 Business planning',
          '3.1.7 Expanding a business',
          'enterprise and entrepreneurship',
          'revenue costs profit and cash',
          'economies and diseconomies of scale',
          'niche and mass markets',
          'risk and reward',
        ],
      ),
      CurriculumSection(
        id: 'operations',
        title: '2. Business Operations and Human Resources',
        topics: [
          '3.3.1 Production processes',
          '3.3.2 The role of procurement and stock control',
          '3.3.3 Quality management',
          '3.3.4 The sales process and customer service',
          '3.4.1 Organisational structures',
          '3.4.2 Effective recruitment',
          '3.4.3 Effective training and development',
          '3.4.4 Motivation',
          '3.4.5 Effective communication',
          'labour productivity and efficiency',
          'capacity utilisation',
          'supply chain management',
        ],
      ),
      CurriculumSection(
        id: 'marketing_finance',
        title: '3. Marketing and Finance',
        topics: [
          '3.5.1 Identifying and understanding customers',
          '3.5.2 Segmentation targeting and positioning',
          '3.5.3 The purpose and methods of market research',
          '3.5.4 Using the marketing mix',
          '3.6.1 Sources of finance',
          '3.6.2 Cash flow',
          '3.6.3 Financial terms and calculations',
          '3.6.4 Analysing the financial performance of a business',
          'product life cycle and extension strategies',
          'pricing strategies and methods',
          'break-even and margin of safety',
          'income statements and statement of financial position',
        ],
      ),
      CurriculumSection(
        id: 'influences',
        title: '4. External Influences and Business Decisions',
        topics: [
          '3.2.1 Technology and business',
          '3.2.2 Ethical and environmental considerations',
          '3.2.3 The economic climate on businesses',
          '3.2.4 Globalisation',
          '3.2.5 Legislation and business',
          '3.2.6 Competitive environment',
          'inflation interest rates and exchange rates',
          'government intervention and regulation',
          'interdependent business decisions',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Influences of Operations and HRM)',
        durationMinutes: 105,
        marks: 90,
        sectionIds: ['business_activity', 'operations', 'influences'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Influences of Marketing and Finance)',
        durationMinutes: 105,
        marks: 90,
        sectionIds: ['business_activity', 'marketing_finance', 'influences'],
      ),
    ],
  ),
  'economics': SubjectCurriculum(
    subject: 'Economics',
    sections: [
      CurriculumSection(
        id: 'micro',
        title: '1. Microeconomics',
        topics: [
          '4.1.1 Economic foundations',
          '4.1.2 Resource allocation',
          '4.1.3 How prices are determined',
          '4.1.4 Production costs revenue and profit',
          '4.1.5 Competitive and concentrated markets',
          '4.1.6 Market failure',
          '4.1.7 Government intervention',
          'demand supply and equilibrium analysis',
          'elasticity and market responsiveness',
          'externalities public goods and information failure',
          'tax subsidies maximum and minimum prices',
          'labour market and wage determination',
        ],
      ),
      CurriculumSection(
        id: 'macro',
        title: '2. Macroeconomics',
        topics: [
          '4.2.1 Macroeconomic measures',
          '4.2.2 Managing the economy',
          '4.2.3 International trade and the global economy',
          'economic growth inflation and unemployment',
          'fiscal policy and monetary policy',
          'supply-side policy and productivity',
          'balance of payments and exchange rates',
          'conflicts between macroeconomic objectives',
          'distribution of income and living standards',
          'role of central banks and government',
        ],
      ),
      CurriculumSection(
        id: 'global',
        title: '3. Global Economy',
        topics: [
          'free trade protectionism and trade barriers',
          'comparative advantage and specialisation',
          'globalisation and multinational corporations',
          'exchange rates and international competitiveness',
          'development indicators and quality of life',
          'causes and consequences of inequality',
          'strategies to promote development',
          'environmental sustainability in growth',
          'role of international organisations',
          'debt aid and fair trade',
          'emerging economies and growth patterns',
          'global shocks and policy response',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (How Markets Work)',
        durationMinutes: 105,
        marks: 100,
        sectionIds: ['micro'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (How the Economy Works)',
        durationMinutes: 105,
        marks: 100,
        sectionIds: ['macro', 'global'],
      ),
    ],
  ),
  'religious studies': SubjectCurriculum(
    subject: 'Religious Studies',
    sections: [
      CurriculumSection(
        id: 'beliefs',
        title: '1. Beliefs and Teachings',
        topics: [
          'nature of god and ultimate reality',
          'creation beliefs and human purpose',
          'incarnation revelation and prophecy',
          'concepts of sin forgiveness and salvation/liberation',
          'life after death and judgement',
          'heaven hell paradise and rebirth beliefs',
          'sources of wisdom and authority',
          'sacred texts and interpretation',
          'key beliefs within denominations/schools',
          'religious teachings applied to modern life',
        ],
      ),
      CurriculumSection(
        id: 'practices',
        title: '2. Practices',
        topics: [
          'forms of worship: liturgical and non-liturgical',
          'private prayer public prayer and meditation',
          'sacraments rites and ceremonies',
          'pilgrimage and sacred places',
          'festivals and their religious significance',
          'charity mission and community action',
          'evangelism and outreach',
          'religious communities and family life',
          'role of places of worship',
          'religion in wider society',
        ],
      ),
      CurriculumSection(
        id: 'themes',
        title: '3. Thematic Ethical Studies',
        topics: [
          'relationships and families',
          'marriage cohabitation divorce and sexuality',
          'gender equality and roles',
          'religion and life: origins and value of life',
          'abortion euthanasia and animal rights',
          'peace conflict war and terrorism',
          'justice forgiveness and reconciliation',
          'crime punishment and the justice system',
          'human rights prejudice and discrimination',
          'social justice wealth poverty and exploitation',
          'religion and equality',
          'religion and secular society',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Religions)',
        durationMinutes: 105,
        marks: 96,
        sectionIds: ['beliefs', 'practices'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Thematic Studies)',
        durationMinutes: 105,
        marks: 96,
        sectionIds: ['themes'],
      ),
    ],
  ),
  'french': SubjectCurriculum(
    subject: 'French',
    sections: [
      CurriculumSection(
        id: 'theme_identity',
        title: 'Identity and Culture',
        topics: [
          'family and relationships',
          'describing people and personality',
          'daily routines and household life',
          'food and eating habits',
          'healthy and unhealthy lifestyles',
          'free-time activities and hobbies',
          'sports music cinema and reading',
          'social media and digital technology',
          'customs festivals and celebrations',
          'local and national culture',
        ],
      ),
      CurriculumSection(
        id: 'theme_local',
        title: 'Local, National, International and Global Areas',
        topics: [
          'home town neighbourhood and region',
          'social issues and volunteering',
          'poverty homelessness and inequality',
          'environmental issues and solutions',
          'recycling sustainability and climate',
          'travel tourism and holidays',
          'accommodation transport and booking',
          'international events and global citizenship',
          'customs traditions and communities abroad',
          'natural world and conservation',
        ],
      ),
      CurriculumSection(
        id: 'theme_future',
        title: 'Current and Future Study and Employment',
        topics: [
          'school subjects and school life',
          'school rules and pressures',
          'future education and university choices',
          'career ambitions and pathways',
          'part-time jobs and responsibilities',
          'work experience and employability skills',
          'applications CVs and interviews',
          'workplace conditions and rights',
          'future plans hopes and aspirations',
          'importance of languages for work',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Listening)',
        durationMinutes: 45,
        marks: 50,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Speaking)',
        durationMinutes: 12,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_3',
        title: 'Paper 3 (Reading)',
        durationMinutes: 60,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_4',
        title: 'Paper 4 (Writing)',
        durationMinutes: 75,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
    ],
  ),
  'spanish': SubjectCurriculum(
    subject: 'Spanish',
    sections: [
      CurriculumSection(
        id: 'theme_identity',
        title: 'Identity and Culture',
        topics: [
          'family and relationships',
          'describing people and personality',
          'daily routines and household life',
          'food and eating habits',
          'healthy and unhealthy lifestyles',
          'free-time activities and hobbies',
          'sports music cinema and reading',
          'social media and digital technology',
          'customs festivals and celebrations',
          'local and national culture',
        ],
      ),
      CurriculumSection(
        id: 'theme_local',
        title: 'Local, National, International and Global Areas',
        topics: [
          'home town neighbourhood and region',
          'social issues and volunteering',
          'poverty homelessness and inequality',
          'environmental issues and solutions',
          'recycling sustainability and climate',
          'travel tourism and holidays',
          'accommodation transport and booking',
          'international events and global citizenship',
          'customs traditions and communities abroad',
          'natural world and conservation',
        ],
      ),
      CurriculumSection(
        id: 'theme_future',
        title: 'Current and Future Study and Employment',
        topics: [
          'school subjects and school life',
          'school rules and pressures',
          'future education and university choices',
          'career ambitions and pathways',
          'part-time jobs and responsibilities',
          'work experience and employability skills',
          'applications CVs and interviews',
          'workplace conditions and rights',
          'future plans hopes and aspirations',
          'importance of languages for work',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Listening)',
        durationMinutes: 45,
        marks: 50,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Speaking)',
        durationMinutes: 12,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_3',
        title: 'Paper 3 (Reading)',
        durationMinutes: 60,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_4',
        title: 'Paper 4 (Writing)',
        durationMinutes: 75,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
    ],
  ),
  'german': SubjectCurriculum(
    subject: 'German',
    sections: [
      CurriculumSection(
        id: 'theme_identity',
        title: 'Identity and Culture',
        topics: [
          'family and relationships',
          'describing people and personality',
          'daily routines and household life',
          'food and eating habits',
          'healthy and unhealthy lifestyles',
          'free-time activities and hobbies',
          'sports music cinema and reading',
          'social media and digital technology',
          'customs festivals and celebrations',
          'local and national culture',
        ],
      ),
      CurriculumSection(
        id: 'theme_local',
        title: 'Local, National, International and Global Areas',
        topics: [
          'home town neighbourhood and region',
          'social issues and volunteering',
          'poverty homelessness and inequality',
          'environmental issues and solutions',
          'recycling sustainability and climate',
          'travel tourism and holidays',
          'accommodation transport and booking',
          'international events and global citizenship',
          'customs traditions and communities abroad',
          'natural world and conservation',
        ],
      ),
      CurriculumSection(
        id: 'theme_future',
        title: 'Current and Future Study and Employment',
        topics: [
          'school subjects and school life',
          'school rules and pressures',
          'future education and university choices',
          'career ambitions and pathways',
          'part-time jobs and responsibilities',
          'work experience and employability skills',
          'applications CVs and interviews',
          'workplace conditions and rights',
          'future plans hopes and aspirations',
          'importance of languages for work',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Listening)',
        durationMinutes: 45,
        marks: 50,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Speaking)',
        durationMinutes: 12,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_3',
        title: 'Paper 3 (Reading)',
        durationMinutes: 60,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
      CurriculumPaper(
        id: 'paper_4',
        title: 'Paper 4 (Writing)',
        durationMinutes: 75,
        marks: 60,
        sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
      ),
    ],
  ),
  'art and design': SubjectCurriculum(
    subject: 'Art and Design',
    sections: [
      CurriculumSection(
        id: 'developing_ideas',
        title: 'Developing Ideas',
        topics: [
          'contextual research and visual investigations',
          'artist and designer references',
          'critical annotation and intent statements',
          'recording observations from primary sources',
          'drawing from direct observation',
          'idea generation through thumbnails and studies',
          'mind maps and concept development',
          'planning personal response themes',
          'experimenting with composition and viewpoint',
          'documenting iterative development',
        ],
      ),
      CurriculumSection(
        id: 'refining_work',
        title: 'Refining Work',
        topics: [
          'media exploration across materials and processes',
          'refining techniques and craftsmanship',
          'testing colour palettes and tonal range',
          'surface texture and mixed media methods',
          'printmaking painting drawing and 3D refinement',
          'digital manipulation and photo-editing where relevant',
          'annotation evaluating successes and limitations',
          'responding to feedback and improving outcomes',
          'linking experimentation to intentions',
        ],
      ),
      CurriculumSection(
        id: 'realisation',
        title: 'Presenting Final Response',
        topics: [
          'planning final outcome and production timeline',
          'selecting and justifying final media choices',
          'constructing final piece with control and purpose',
          'communication of personal intentions',
          'coherent connection to research and development',
          'presentation and curation of final work',
          'written and visual evaluation of outcome',
          'reflecting on strengths improvements and next steps',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'component_1',
        title: 'Component 1 (Portfolio)',
        durationMinutes: 0,
        marks: 96,
        sectionIds: ['developing_ideas', 'refining_work'],
      ),
      CurriculumPaper(
        id: 'component_2',
        title: 'Component 2 (Externally Set Assignment)',
        durationMinutes: 600,
        marks: 96,
        sectionIds: ['realisation'],
      ),
    ],
  ),
  'design and technology': SubjectCurriculum(
    subject: 'Design and Technology',
    sections: [
      CurriculumSection(
        id: 'core_technical',
        title: 'Core Technical Principles',
        topics: [
          'new and emerging technologies',
          'energy generation and storage',
          'smart modern and composite materials',
          'mechanical and electronic systems',
          'forces stresses and structural analysis',
          'ecological and social footprint of products',
          'manufacturing scales and production methods',
          'quality control and assurance principles',
          'designing for maintenance and repair',
          'sustainability in material and process choice',
        ],
      ),
      CurriculumSection(
        id: 'specialist_technical',
        title: 'Specialist Technical Principles',
        topics: [
          'selection of materials for function and aesthetics',
          'working properties of timbers metals and polymers',
          'specialist tools and equipment',
          'specialist manufacturing processes',
          'tolerances and precision in production',
          'surface treatments and finishes',
          'commercial manufacturing systems',
          'quality control testing and inspection',
          'stock forms sizes and standard components',
        ],
      ),
      CurriculumSection(
        id: 'designing_making',
        title: 'Designing and Making Principles',
        topics: [
          'identifying user needs and design contexts',
          'writing design briefs and specifications',
          'iterative design and idea modelling',
          'design communication: sketches CAD and annotation',
          'modelling and prototyping methods',
          'planning for manufacture',
          'making techniques and safe working',
          'testing against specification',
          'evaluation and iterative improvements',
          'NEA project management and evidence presentation',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Written Exam)',
        durationMinutes: 120,
        marks: 100,
        sectionIds: [
          'core_technical',
          'specialist_technical',
          'designing_making'
        ],
      ),
      CurriculumPaper(
        id: 'nea',
        title: 'NEA (Design and Make Task)',
        durationMinutes: 1200,
        marks: 100,
        sectionIds: ['designing_making'],
      ),
    ],
  ),
  'drama': SubjectCurriculum(
    subject: 'Drama',
    sections: [
      CurriculumSection(
        id: 'understanding_drama',
        title: 'Understanding Drama',
        topics: [
          'set text knowledge and interpretation',
          'character intention and motivation',
          'genre style and theatrical conventions',
          'staging proxemics and blocking',
          'lighting sound costume and set design',
          'actor audience relationship',
          'evaluating live theatre performance',
          'dramatic structure and pacing',
          'performance analysis using subject terminology',
          'writing structured drama evaluations',
        ],
      ),
      CurriculumSection(
        id: 'devising',
        title: 'Devising Theatre',
        topics: [
          'stimulus exploration and response',
          'devising process and collaborative creation',
          'developing narrative and dramatic intentions',
          'rehearsal methods and refinement',
          'practical performance skills',
          'use of theatre conventions in devised work',
          'creative logbook and process evidence',
          'evaluating decisions and final outcomes',
          'responding to feedback in rehearsal',
        ],
      ),
      CurriculumSection(
        id: 'texts_in_practice',
        title: 'Texts in Practice',
        topics: [
          'script analysis for performance',
          'realising character through voice and movement',
          'director interpretation and concept',
          'duologue and ensemble performance skills',
          'rehearsing scripted extracts',
          'evaluating performance choices',
          'communicating intention to audience',
          'responding to text and context',
          'performance review and improvement planning',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Understanding Drama)',
        durationMinutes: 105,
        marks: 80,
        sectionIds: ['understanding_drama'],
      ),
      CurriculumPaper(
        id: 'component_2',
        title: 'Component 2 (Devising)',
        durationMinutes: 600,
        marks: 80,
        sectionIds: ['devising'],
      ),
      CurriculumPaper(
        id: 'component_3',
        title: 'Component 3 (Texts in Practice)',
        durationMinutes: 120,
        marks: 80,
        sectionIds: ['texts_in_practice'],
      ),
    ],
  ),
  'music': SubjectCurriculum(
    subject: 'Music',
    sections: [
      CurriculumSection(
        id: 'listening',
        title: 'Listening and Appraising',
        topics: [
          'set works familiarity and context',
          'analysis of melody harmony rhythm and tonality',
          'musical forms and structures',
          'texture timbre and instrumentation',
          'tempo dynamics and articulation',
          'identifying genres styles and periods',
          'aural perception and dictation skills',
          'comparing musical extracts',
          'extended written appraising responses',
          'use of subject-specific musical vocabulary',
        ],
      ),
      CurriculumSection(
        id: 'performance',
        title: 'Performing',
        topics: [
          'solo performance technique and interpretation',
          'ensemble coordination and communication',
          'accuracy of pitch rhythm and timing',
          'expression phrasing and dynamics',
          'technical control and fluency',
          'rehearsal planning and reflective improvement',
          'stylistic awareness in performance',
          'stage presence and confidence',
          'recording and submitting performance evidence',
        ],
      ),
      CurriculumSection(
        id: 'composition',
        title: 'Composing',
        topics: [
          'responding to composition briefs',
          'developing musical ideas and motifs',
          'structure and coherence in composition',
          'harmonic and melodic writing techniques',
          'rhythmic development and texture',
          'instrumentation and arranging decisions',
          'notation and sequencing software',
          'refining and redrafting compositions',
          'evaluating compositional outcomes',
          'documenting creative process and rationale',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Listening and Appraising)',
        durationMinutes: 105,
        marks: 96,
        sectionIds: ['listening'],
      ),
      CurriculumPaper(
        id: 'component_2',
        title: 'Component 2 (Performing)',
        durationMinutes: 360,
        marks: 72,
        sectionIds: ['performance'],
      ),
      CurriculumPaper(
        id: 'component_3',
        title: 'Component 3 (Composing)',
        durationMinutes: 360,
        marks: 72,
        sectionIds: ['composition'],
      ),
    ],
  ),
  'physical education': SubjectCurriculum(
    subject: 'Physical Education',
    sections: [
      CurriculumSection(
        id: 'anatomy',
        title: 'Applied Anatomy and Physiology',
        topics: [
          'skeletal system structure and function',
          'muscular system and movement analysis',
          'planes and axes of movement',
          'cardio-respiratory system at rest and during exercise',
          'aerobic and anaerobic exercise',
          'short-term effects of exercise',
          'long-term training adaptations',
          'fitness components and testing',
          'principles of training and overload',
          'injury prevention warm-up and cool-down',
        ],
      ),
      CurriculumSection(
        id: 'socio',
        title: 'Socio-Cultural Influences',
        topics: [
          'engagement patterns in physical activity',
          'participation barriers and strategies to overcome',
          'commercialisation of sport',
          'sponsorship and media influences',
          'role models and social influences',
          'spectatorship and fan behaviour',
          'ethical issues in sport',
          'drugs violence and corruption in sport',
          'governance and sporting values',
          'health wellbeing and lifestyle links',
        ],
      ),
      CurriculumSection(
        id: 'performance',
        title: 'Practical Performance and Coursework',
        topics: [
          'performance in three practical activities',
          'skills techniques and tactical decision making',
          'performance consistency under pressure',
          'application of rules and regulations',
          'personal exercise programme planning',
          'goal setting and training programme design',
          'analysis of strengths and weaknesses',
          'evaluation and action plan for improvement',
          'recording evidence and assessment criteria',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1 (Physical Factors)',
        durationMinutes: 75,
        marks: 78,
        sectionIds: ['anatomy'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2 (Socio-Cultural Factors)',
        durationMinutes: 75,
        marks: 78,
        sectionIds: ['socio'],
      ),
      CurriculumPaper(
        id: 'nea',
        title: 'NEA (Practical Performance)',
        durationMinutes: 240,
        marks: 84,
        sectionIds: ['performance'],
      ),
    ],
  ),
  'statistics': SubjectCurriculum(
    subject: 'Statistics',
    sections: [
      CurriculumSection(
        id: 'data_collection',
        title: 'Collection of Data',
        topics: [
          'types of data: qualitative quantitative discrete continuous',
          'sampling methods and representativeness',
          'questionnaire design and pilot studies',
          'sources of bias and reliability',
          'primary and secondary data collection',
          'population and sample distinction',
          'large data sets and data ethics',
          'planning statistical investigations',
          'critique of data collection methods',
        ],
      ),
      CurriculumSection(
        id: 'processing',
        title: 'Processing and Representation',
        topics: [
          'frequency tables and grouped data',
          'bar charts pie charts and frequency polygons',
          'histograms and frequency density',
          'cumulative frequency graphs',
          'box plots and comparative distribution analysis',
          'time series and moving averages',
          'scatter graphs and line of best fit',
          'interpolation extrapolation and misuse of graphs',
          'using technology for data representation',
        ],
      ),
      CurriculumSection(
        id: 'analysis_probability',
        title: 'Analysis and Probability',
        topics: [
          'mean median mode and weighted averages',
          'range interquartile range and standard deviation',
          'percentiles and quartiles',
          'probability rules and sample space diagrams',
          'tree diagrams and conditional probability',
          'independence and mutually exclusive events',
          'expected value and risk assessment',
          'correlation and causation',
          'statistical inference and drawing conclusions',
          'critical interpretation of statistical claims',
        ],
      ),
    ],
    papers: [
      CurriculumPaper(
        id: 'paper_1',
        title: 'Paper 1',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['data_collection', 'processing'],
      ),
      CurriculumPaper(
        id: 'paper_2',
        title: 'Paper 2',
        durationMinutes: 90,
        marks: 80,
        sectionIds: ['analysis_probability', 'processing'],
      ),
    ],
  ),
};

const Set<String> _trustedGcseCurriculumSubjects = {
  'mathematics',
  'english language',
  'english literature',
  'combined science',
  'biology',
  'chemistry',
  'physics',
  'history',
  'geography',
  'computer science',
  'business',
  'economics',
};

SubjectCurriculum _fallbackGcseCurriculum(String subject) {
  const paperCount = 2;

  final sections = [
    CurriculumSection(
      id: 'core_knowledge',
      title: 'Core Knowledge',
      topics: [subject.toLowerCase(), 'terminology', 'key facts', 'methods'],
    ),
    CurriculumSection(
      id: 'application',
      title: 'Application and Problem Solving',
      topics: ['application', 'reasoning', 'case study', 'analysis'],
    ),
    CurriculumSection(
      id: 'exam_skills',
      title: 'Exam Technique and Evaluation',
      topics: ['evaluation', 'timing', 'extended response', 'exam strategy'],
    ),
  ];

  final papers = List.generate(paperCount, (index) {
    return CurriculumPaper(
      id: 'paper_${index + 1}',
      title: 'Paper ${index + 1}',
      durationMinutes: 90,
      marks: 80,
      sectionIds: sections.map((section) => section.id).toList(),
    );
  });

  return SubjectCurriculum(
    subject: subject,
    sections: sections,
    papers: papers,
  );
}

List<CurriculumPaper> _gcseBoardPapers({
  required String subjectKey,
  required String boardKey,
  required List<CurriculumSection> sections,
  required List<CurriculumPaper> base,
}) {
  List<CurriculumPaper> withMeta(
    List<CurriculumPaper> papers, {
    List<String>? tiers,
    int? weightPercent,
  }) {
    return papers
        .map(
          (paper) => CurriculumPaper(
            id: paper.id,
            title: paper.title,
            durationMinutes: paper.durationMinutes,
            marks: paper.marks,
            sectionIds: paper.sectionIds,
            tiers: tiers ?? paper.tiers,
            weightPercent: weightPercent ?? paper.weightPercent,
          ),
        )
        .toList();
  }

  List<CurriculumPaper> applyDefaultMeta(List<CurriculumPaper> papers) {
    switch (subjectKey) {
      case 'mathematics':
        return withMeta(papers,
            tiers: const ['Foundation', 'Higher'], weightPercent: 33);
      case 'combined science':
        return withMeta(papers,
            tiers: const ['Foundation', 'Higher'], weightPercent: 17);
      case 'biology':
      case 'chemistry':
      case 'physics':
        return withMeta(papers,
            tiers: const ['Foundation', 'Higher'], weightPercent: 50);
      case 'french':
      case 'spanish':
      case 'german':
        return withMeta(papers,
            tiers: const ['Foundation', 'Higher'], weightPercent: 25);
      default:
        return papers;
    }
  }

  List<CurriculumPaper> named(List<CurriculumPaper> papers) {
    final prepared = applyDefaultMeta(papers);
    return prepared
        .map(
          (paper) => CurriculumPaper(
            id: paper.id,
            title: paper.title,
            durationMinutes: paper.durationMinutes,
            marks: paper.marks,
            sectionIds: paper.sectionIds,
            tiers: paper.tiers,
            weightPercent: paper.weightPercent,
          ),
        )
        .toList();
  }

  switch (subjectKey) {
    case 'mathematics':
      if (boardKey == 'aqa' || boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Non-Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['number', 'algebra', 'geometry'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['algebra', 'geometry', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['number', 'algebra', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Non-Calculator)',
            durationMinutes: 90,
            marks: 100,
            sectionIds: ['number', 'algebra', 'geometry'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Calculator)',
            durationMinutes: 90,
            marks: 100,
            sectionIds: ['algebra', 'geometry', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Calculator)',
            durationMinutes: 90,
            marks: 100,
            sectionIds: ['number', 'algebra', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Non-Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['number', 'algebra', 'geometry'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['algebra', 'geometry', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
          CurriculumPaper(
            id: 'unit_3',
            title: 'Unit 3 (Calculator)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['number', 'algebra', 'stats_prob'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 33,
          ),
        ]);
      }
      return named(base);
    case 'english language':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Explorations in Creative Reading and Writing)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['reading_fiction', 'writing'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Writers Viewpoints and Perspectives)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['reading_nonfiction', 'writing'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Fiction and Imaginative Writing)',
            durationMinutes: 105,
            marks: 64,
            sectionIds: ['reading_fiction', 'writing'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Non-Fiction and Transactional Writing)',
            durationMinutes: 120,
            marks: 96,
            sectionIds: ['reading_nonfiction', 'writing'],
            weightPercent: 60,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Communicating Information and Ideas)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['reading_nonfiction', 'writing'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Exploring Effects and Impact)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['reading_fiction', 'writing'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (20th/21st Century and Creative Writing)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['reading_nonfiction', 'writing'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Literary Reading and Transactional Writing)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['reading_fiction', 'writing'],
            weightPercent: 60,
          ),
        ]);
      }
      return named(base);
    case 'english literature':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Shakespeare and 19th-Century Novel)',
            durationMinutes: 105,
            marks: 64,
            sectionIds: ['shakespeare', '19th_novel'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Modern Text and Poetry)',
            durationMinutes: 135,
            marks: 96,
            sectionIds: ['modern_text', 'poetry'],
            weightPercent: 60,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Shakespeare and 19th-Century Novel)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['shakespeare', '19th_novel'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Modern Text and Poetry)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['modern_text', 'poetry'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Shakespeare and Post-1914 Literature)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['shakespeare', 'modern_text'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (19th-Century Novel and Poetry Since 1789)',
            durationMinutes: 135,
            marks: 80,
            sectionIds: ['19th_novel', 'poetry'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Shakespeare and Poetry)',
            durationMinutes: 120,
            marks: 80,
            sectionIds: ['shakespeare', 'poetry'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Post-1914 and 19th-Century Prose)',
            durationMinutes: 150,
            marks: 80,
            sectionIds: ['modern_text', '19th_novel'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'french':
    case 'spanish':
    case 'german':
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Listening)',
            durationMinutes: 45,
            marks: 50,
            sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 25,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Speaking)',
            durationMinutes: 12,
            marks: 60,
            sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 25,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Reading)',
            durationMinutes: 60,
            marks: 60,
            sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 25,
          ),
          CurriculumPaper(
            id: 'paper_4',
            title: 'Paper 4 (Writing)',
            durationMinutes: 75,
            marks: 60,
            sectionIds: ['theme_identity', 'theme_local', 'theme_future'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 25,
          ),
        ]);
      }
      return named(base);
    case 'art and design':
      if (boardKey == 'aqa' ||
          boardKey == 'ocr' ||
          boardKey == 'pearson edexcel' ||
          boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Portfolio)',
            durationMinutes: 0,
            marks: 96,
            sectionIds: ['developing_ideas', 'refining_work'],
            weightPercent: 60,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Externally Set Assignment)',
            durationMinutes: 600,
            marks: 96,
            sectionIds: ['realisation'],
            weightPercent: 40,
          ),
        ]);
      }
      return named(base);
    case 'design and technology':
      if (boardKey == 'aqa' ||
          boardKey == 'ocr' ||
          boardKey == 'pearson edexcel' ||
          boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Written Exam)',
            durationMinutes: boardKey == 'pearson edexcel' ? 105 : 120,
            marks: 100,
            sectionIds: [
              'core_technical',
              'specialist_technical',
              'designing_making'
            ],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'nea',
            title: 'NEA (Design and Make Task)',
            durationMinutes: 1200,
            marks: 100,
            sectionIds: ['designing_making'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'drama':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Understanding Drama)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['understanding_drama'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Devising Drama)',
            durationMinutes: 600,
            marks: 80,
            sectionIds: ['devising'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Texts in Practice)',
            durationMinutes: 120,
            marks: 40,
            sectionIds: ['texts_in_practice'],
            weightPercent: 20,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Devising)',
            durationMinutes: 600,
            marks: 60,
            sectionIds: ['devising'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Performance from Text)',
            durationMinutes: 120,
            marks: 48,
            sectionIds: ['texts_in_practice'],
            weightPercent: 20,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Theatre Makers in Practice)',
            durationMinutes: 105,
            marks: 84,
            sectionIds: ['understanding_drama'],
            weightPercent: 40,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Performance and Response)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['understanding_drama', 'texts_in_practice'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Devising Drama)',
            durationMinutes: 600,
            marks: 80,
            sectionIds: ['devising'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Presenting and Performing Texts)',
            durationMinutes: 120,
            marks: 40,
            sectionIds: ['texts_in_practice'],
            weightPercent: 20,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Devising Theatre)',
            durationMinutes: 600,
            marks: 80,
            sectionIds: ['devising'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Performing from a Text)',
            durationMinutes: 120,
            marks: 40,
            sectionIds: ['texts_in_practice'],
            weightPercent: 20,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Interpreting Theatre)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['understanding_drama'],
            weightPercent: 40,
          ),
        ]);
      }
      return named(base);
    case 'music':
      if (boardKey == 'aqa' ||
          boardKey == 'ocr' ||
          boardKey == 'pearson edexcel' ||
          boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Listening and Appraising)',
            durationMinutes: 105,
            marks: 96,
            sectionIds: ['listening'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Performing)',
            durationMinutes: 360,
            marks: 72,
            sectionIds: ['performance'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Composing)',
            durationMinutes: 360,
            marks: 72,
            sectionIds: ['composition'],
            weightPercent: 30,
          ),
        ]);
      }
      return named(base);
    case 'combined science':
      if (boardKey == 'aqa' || boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'bio_paper_1',
            title: 'Biology Paper 1',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['bio_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'bio_paper_2',
            title: 'Biology Paper 2',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['bio_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'chem_paper_1',
            title: 'Chemistry Paper 1',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['chem_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'chem_paper_2',
            title: 'Chemistry Paper 2',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['chem_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'phys_paper_1',
            title: 'Physics Paper 1',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['phys_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'phys_paper_2',
            title: 'Physics Paper 2',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['phys_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'bio_a',
            title: 'Biology A (Modules B1-B3)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['bio_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'bio_b',
            title: 'Biology B (Modules B4-B6)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['bio_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'chem_a',
            title: 'Chemistry A (Modules C1-C3)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['chem_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'chem_b',
            title: 'Chemistry B (Modules C4-C6)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['chem_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'phys_a',
            title: 'Physics A (Modules P1-P3)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['phys_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'phys_b',
            title: 'Physics B (Modules P4-P6)',
            durationMinutes: 70,
            marks: 70,
            sectionIds: ['phys_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Biology)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['bio_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Chemistry)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['chem_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'unit_3',
            title: 'Unit 3 (Physics)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['phys_paper_1_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'unit_4',
            title: 'Unit 4 (Biology 2)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['bio_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'unit_5',
            title: 'Unit 5 (Chemistry 2)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['chem_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
          CurriculumPaper(
            id: 'unit_6',
            title: 'Unit 6 (Physics 2)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['phys_paper_2_topics'],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 17,
          ),
        ]);
      }
      return named(base);
    case 'biology':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title:
                'Paper 1 (Cell Biology, Organisation, Infection and Bioenergetics)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'key_concepts',
              'cells_control',
              'health_disease_medicine',
              'plant_structures',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Homeostasis, Inheritance and Ecology)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'genetics',
              'natural_selection_and_modification',
              'animal_coordination_homeostasis',
              'exchange_transport_animals',
              'ecosystems_material_cycles',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Cell-Level Systems)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'key_concepts',
              'cells_control',
              'health_disease_medicine',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Scaling Up and Ecosystems)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'genetics',
              'animal_coordination_homeostasis',
              'exchange_transport_animals',
              'ecosystems_material_cycles',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Key Concepts, Cells, Genetics and Health)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'key_concepts',
              'cells_control',
              'genetics',
              'health_disease_medicine',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Plants, Homeostasis and Ecosystems)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'plant_structures',
              'animal_coordination_homeostasis',
              'exchange_transport_animals',
              'ecosystems_material_cycles',
              'natural_selection_and_modification',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Biology 1)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'key_concepts',
              'cells_control',
              'health_disease_medicine',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Biology 2)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'genetics',
              'animal_coordination_homeostasis',
              'exchange_transport_animals',
              'ecosystems_material_cycles',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'chemistry':
      if (boardKey == 'aqa' || boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title:
                'Paper 1 (Atomic Structure, Bonding, Quantitative and Chemical Changes)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'atomic_and_periodic',
              'bonding_structure_properties',
              'quantitative_chemistry',
              'chemical_changes',
              'energy_changes',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Rates, Organic, Analysis and Resources)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'rates_equilibrium',
              'organic_chemistry',
              'chemical_analysis',
              'atmosphere_resources',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Breadth in Chemistry)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'atomic_and_periodic',
              'bonding_structure_properties',
              'quantitative_chemistry',
              'energy_changes',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Depth in Chemistry)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'chemical_changes',
              'rates_equilibrium',
              'organic_chemistry',
              'chemical_analysis',
              'atmosphere_resources',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Chemistry 1)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'atomic_and_periodic',
              'bonding_structure_properties',
              'quantitative_chemistry',
              'chemical_changes',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Chemistry 2)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'energy_changes',
              'rates_equilibrium',
              'organic_chemistry',
              'chemical_analysis',
              'atmosphere_resources',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'physics':
      if (boardKey == 'aqa' || boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title:
                'Paper 1 (Energy, Electricity, Particles and Atomic Structure)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'energy_transfers',
              'electricity',
              'particles',
              'atomic_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Forces, Waves and Magnetism)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'forces',
              'waves',
              'magnetism_electromagnetism',
              'space_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Breadth in Physics)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'energy_transfers',
              'electricity',
              'particles',
              'atomic_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Depth in Physics)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: [
              'forces',
              'waves',
              'magnetism_electromagnetism',
              'space_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Physics 1)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'energy_transfers',
              'electricity',
              'particles',
              'atomic_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Physics 2)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: [
              'forces',
              'waves',
              'magnetism_electromagnetism',
              'space_physics',
            ],
            tiers: const ['Foundation', 'Higher'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'history':
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Period and Thematic Study)',
            durationMinutes: 105,
            marks: 80,
            sectionIds: ['period_study', 'british'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (British Depth Study)',
            durationMinutes: 60,
            marks: 40,
            sectionIds: ['depth_study'],
            weightPercent: 20,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (World Depth Study)',
            durationMinutes: 75,
            marks: 40,
            sectionIds: ['depth_study'],
            weightPercent: 40,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Thematic Study and Historic Environment)',
            durationMinutes: 75,
            marks: 52,
            sectionIds: ['british'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Period and British Depth)',
            durationMinutes: 105,
            marks: 64,
            sectionIds: ['period_study', 'depth_study'],
            weightPercent: 40,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Modern Depth Study)',
            durationMinutes: 90,
            marks: 52,
            sectionIds: ['depth_study'],
            weightPercent: 30,
          ),
        ]);
      }
      return named(base);
    case 'geography':
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Our Natural World)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['physical'],
            weightPercent: 35,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (People and Society)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['human'],
            weightPercent: 35,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Geographical Exploration)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['skills'],
            weightPercent: 30,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (The Physical Environment)',
            durationMinutes: 90,
            marks: 94,
            sectionIds: ['physical'],
            weightPercent: 37,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (The Human Environment)',
            durationMinutes: 90,
            marks: 94,
            sectionIds: ['human'],
            weightPercent: 37,
          ),
          CurriculumPaper(
            id: 'paper_3',
            title: 'Paper 3 (Geographical Investigations)',
            durationMinutes: 75,
            marks: 64,
            sectionIds: ['skills'],
            weightPercent: 26,
          ),
        ]);
      }
      return named(base);
    case 'business':
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Investigating Small Business)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: ['business_activity', 'operations', 'influences'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Building a Business)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: ['marketing_finance', 'operations', 'influences'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Business Activity, Marketing and People)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: [
              'business_activity',
              'marketing_finance',
              'influences'
            ],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Operations, Finance and Influences)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['operations', 'marketing_finance', 'influences'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'economics':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (How Markets Work)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: ['micro'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (How the Economy Works)',
            durationMinutes: 105,
            marks: 100,
            sectionIds: ['macro', 'global'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (The Market System)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['micro'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (National and Global Economy)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['macro', 'global'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'computer science':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Computational Thinking and Programming)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: ['algorithms', 'data'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Computing Concepts)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: ['systems', 'data'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Computer Systems)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['systems', 'data'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Computational Thinking and Programming)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['algorithms'],
            weightPercent: 50,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Understanding Computer Science)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['systems', 'data'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Applying Computational Thinking)',
            durationMinutes: 90,
            marks: 80,
            sectionIds: ['algorithms'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'religious studies':
      if (boardKey == 'aqa' || boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Religions)',
            durationMinutes: 105,
            marks: 96,
            sectionIds: ['beliefs', 'practices'],
            weightPercent: 50,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Thematic Studies)',
            durationMinutes: 105,
            marks: 96,
            sectionIds: ['themes'],
            weightPercent: 50,
          ),
        ]);
      }
      return named(base);
    case 'physical education':
      if (boardKey == 'aqa') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (The Human Body and Movement)',
            durationMinutes: 75,
            marks: 78,
            sectionIds: ['anatomy'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Socio-Cultural Influences and Wellbeing)',
            durationMinutes: 75,
            marks: 78,
            sectionIds: ['socio'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'nea',
            title: 'NEA (Practical Performance and Analysis)',
            durationMinutes: 240,
            marks: 100,
            sectionIds: ['performance'],
            weightPercent: 40,
          ),
        ]);
      }
      if (boardKey == 'ocr') {
        return named([
          CurriculumPaper(
            id: 'paper_1',
            title: 'Paper 1 (Physical Factors Affecting Performance)',
            durationMinutes: 60,
            marks: 60,
            sectionIds: ['anatomy'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'paper_2',
            title: 'Paper 2 (Socio-Cultural Issues and Sports Psychology)',
            durationMinutes: 60,
            marks: 60,
            sectionIds: ['socio'],
            weightPercent: 30,
          ),
          CurriculumPaper(
            id: 'nea',
            title: 'NEA (Performance and Evaluating Performance)',
            durationMinutes: 240,
            marks: 80,
            sectionIds: ['performance'],
            weightPercent: 40,
          ),
        ]);
      }
      if (boardKey == 'pearson edexcel') {
        return named([
          CurriculumPaper(
            id: 'component_1',
            title: 'Component 1 (Fitness and Body Systems)',
            durationMinutes: 90,
            marks: 90,
            sectionIds: ['anatomy'],
            weightPercent: 36,
          ),
          CurriculumPaper(
            id: 'component_2',
            title: 'Component 2 (Health and Performance)',
            durationMinutes: 75,
            marks: 70,
            sectionIds: ['socio'],
            weightPercent: 24,
          ),
          CurriculumPaper(
            id: 'component_3',
            title: 'Component 3 (Practical and Personal Exercise Programme)',
            durationMinutes: 240,
            marks: 105,
            sectionIds: ['performance'],
            weightPercent: 40,
          ),
        ]);
      }
      if (boardKey == 'wjec') {
        return named([
          CurriculumPaper(
            id: 'unit_1',
            title: 'Unit 1 (Health, Training and Exercise)',
            durationMinutes: 120,
            marks: 120,
            sectionIds: ['anatomy', 'socio'],
            weightPercent: 60,
          ),
          CurriculumPaper(
            id: 'unit_2',
            title: 'Unit 2 (Practical Performance and Personal Fitness)',
            durationMinutes: 240,
            marks: 80,
            sectionIds: ['performance'],
            weightPercent: 40,
          ),
        ]);
      }
      return named(base);
    case 'statistics':
      return named([
        CurriculumPaper(
          id: 'paper_1',
          title: 'Paper 1',
          durationMinutes: 90,
          marks: 80,
          sectionIds: ['data_collection', 'processing'],
          tiers: const ['Foundation', 'Higher'],
          weightPercent: 50,
        ),
        CurriculumPaper(
          id: 'paper_2',
          title: 'Paper 2',
          durationMinutes: 90,
          marks: 80,
          sectionIds: ['analysis_probability', 'processing'],
          tiers: const ['Foundation', 'Higher'],
          weightPercent: 50,
        ),
      ]);
    default:
      return named(base);
  }
}

String _stripSectionNumbering(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return title;
  final stripped = trimmed.replaceFirst(
    RegExp(r'^\d+(?:\.\d+)?\s*[\.\)]\s*'),
    '',
  );
  return stripped.trim().isEmpty ? trimmed : stripped.trim();
}

String _cleanTopicLabel(String topic) {
  var value = topic.trim();
  if (value.isEmpty) return '';
  value = value.replaceAll(RegExp(r'\s+'), ' ');
  return value;
}

String _topicKey(String topic) {
  return topic
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _curateTopics(List<String> topics) {
  const maxTopicsPerSection = 12;
  final curated = <String>[];
  final seen = <String>{};

  for (final raw in topics) {
    final cleaned = _cleanTopicLabel(raw);
    if (cleaned.isEmpty) continue;
    final key = _topicKey(cleaned);
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    curated.add(cleaned);
    if (curated.length >= maxTopicsPerSection) break;
  }

  if (curated.isNotEmpty) {
    return curated;
  }

  return const [
    'core knowledge',
    'application questions',
    'exam technique',
  ];
}

SubjectCurriculum _qualityTuneCurriculum(SubjectCurriculum curriculum) {
  final tunedSections = curriculum.sections
      .map(
        (section) => CurriculumSection(
          id: section.id,
          title: _stripSectionNumbering(section.title),
          topics: _curateTopics(section.topics),
        ),
      )
      .toList();

  final validSectionIds = tunedSections.map((section) => section.id).toSet();

  final tunedPapers = curriculum.papers.map((paper) {
    final validIds = paper.sectionIds
        .where((sectionId) => validSectionIds.contains(sectionId))
        .toList();
    final fallbackIds = validIds.isNotEmpty || tunedSections.isEmpty
        ? validIds
        : [tunedSections.first.id];
    return CurriculumPaper(
      id: paper.id,
      title: paper.title.replaceAll(RegExp(r'\s+'), ' ').trim(),
      durationMinutes: paper.durationMinutes,
      marks: paper.marks,
      sectionIds: fallbackIds,
      tiers: paper.tiers,
      weightPercent: paper.weightPercent,
    );
  }).toList();

  return SubjectCurriculum(
    subject: curriculum.subject,
    sections: tunedSections,
    papers: tunedPapers,
  );
}

SubjectCurriculum? curriculumFor(
  String examFamily,
  String subject, {
  String? board,
}) {
  final family = _normalize(examFamily);
  final key = _normalize(subject);
  final boardKey = _normalize(board ?? '');

  if (family == 'gcse') {
    final hasTrustedTemplate = _trustedGcseCurriculumSubjects.contains(key);
    final base = hasTrustedTemplate
        ? (_gcseCurriculum[key] ?? _fallbackGcseCurriculum(subject))
        : _fallbackGcseCurriculum(subject);
    final resolved = SubjectCurriculum(
      subject: base.subject,
      sections: base.sections,
      papers: _gcseBoardPapers(
        subjectKey: key,
        boardKey: boardKey,
        sections: base.sections,
        base: base.papers,
      ),
    );
    return _qualityTuneCurriculum(resolved);
  }
  return null;
}
